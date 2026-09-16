use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;
use Plack::Test;
use HTTP::Request::Common;
use Path::Tiny ();

use Dancer2::Template::TemplateToolkit;

# Template rendering: whether the layout is applied, which layout, and what
# tokens a view can count on.
#
# The layout decision is made in Role::Template::apply_layout
# (Dancer2/Core/Role/Template.pm:169-172) and distinguishes three cases that are
# easy to collapse into two by accident:
#
#   layout key absent from options  -> use the configured layout
#   layout key present and true     -> use *that* layout
#   layout key present and false    -> no layout at all
#
# Template::Toolkit is used rather than Template::Tiny because it is stricter
# about undefined tokens and is what most applications actually run.

my $VIEWS;
BEGIN {
    $VIEWS = Path::Tiny->tempdir;
    $VIEWS->child('layouts')->mkpath;

    $VIEWS->child('body.tt')->spew_utf8('BODY');
    $VIEWS->child('empty.tt')->spew_utf8('');
    $VIEWS->child( 'layouts', 'main.tt' )->spew_utf8('MAIN{[% content %]}');
    $VIEWS->child( 'layouts', 'alt.tt' )->spew_utf8('ALT{[% content %]}');

    # Every default token, reported so a missing one is visible rather than
    # silently rendering as empty.
    $VIEWS->child('tokens.tt')->spew_utf8(
        join ' ',
        'settings=[% settings.some_setting %]',
        'param=[% params.q %]',
        'var=[% vars.myvar %]',
        'session=[% session.who %]',
        'request=[% request.path %]',
        'perl=[% perl_version %]',
        'dancer=[% dancer_version %]',
    );
}

{
    package TemplateApp;
    use Dancer2;
    set logger       => 'null';
    set views        => $VIEWS->stringify;
    set template     => 'template_toolkit';
    set layout       => 'main';
    set session      => 'Simple';
    set some_setting => 'SETTING-VALUE';

    get '/configured' => sub { template 'body' };
    get '/suppressed' => sub { template 'body', {}, { layout => 0 } };
    get '/undef'      => sub { template 'body', {}, { layout => undef } };
    get '/named'      => sub { template 'body', {}, { layout => 'alt' } };
    get '/empty'      => sub { template 'empty', {}, { layout => 0 } };

    get '/tokens' => sub {
        var myvar    => 'VAR-VALUE';
        session who  => 'ovid';
        template 'tokens', {}, { layout => 0 };
    };
}

my $test = Plack::Test->create( TemplateApp->to_app );

subtest 'the configured layout is applied by default' => sub {
    my $response = $test->request( GET '/configured' );

    is( $response->code, 200, 'the page renders' );
    is( $response->content, 'MAIN{BODY}',
        'the view is wrapped in the configured layout' );
};

subtest 'a false layout option suppresses the layout entirely' => sub {
    # 0 and undef are the two ways of saying "no layout", and they go through
    # different halves of the ternary at Role/Template.pm:169-172.
    is( $test->request( GET '/suppressed' )->content, 'BODY',
        'layout => 0 renders the view with no layout' );
    is( $test->request( GET '/undef' )->content, 'BODY',
        'layout => undef does the same' );

    # The control: the same view under the same app does get a layout when the
    # option is absent, so the two above are suppressing something real.
    is( $test->request( GET '/configured' )->content, 'MAIN{BODY}',
        'while omitting the option still uses the configured layout' );
};

subtest 'a named layout option beats the configured layout' => sub {
    my $response = $test->request( GET '/named' );

    is( $response->content, 'ALT{BODY}',
        'the layout named in the options is used' );
    unlike( $response->content, qr/MAIN/,
        'and the configured layout is not applied as well' );
};

subtest 'a view is given the default tokens' => sub {
    my $response = $test->request( GET '/tokens?q=PARAM-VALUE' );
    my $body     = $response->content;

    is( $response->code, 200, 'the page renders' );

    # Each of these is a separate assertion so a failure names the token that
    # went missing rather than just reporting the whole line differs.
    like( $body, qr/\bsettings=SETTING-VALUE\b/, 'settings token is present' );
    like( $body, qr/\bparam=PARAM-VALUE\b/,      'params token is present' );
    like( $body, qr/\bvar=VAR-VALUE\b/,          'vars token is present' );
    like( $body, qr/\bsession=ovid\b/,           'session token is present' );
    like( $body, qr{\brequest=/tokens\b},        'request token is present' );
    like( $body, qr/\bperl=v\d+\.\d+/,           'perl_version token is present' );
    like( $body, qr/\bdancer=\d/,                'dancer_version token is present' );
};

subtest 'an empty view renders as empty, and does not raise' => sub {
    # Pinned as current behavior. An empty view file produces an empty string,
    # which is defined, so it passes straight through apply_layout and process
    # without tripping the "did not produce any content" guard.
    my $response = $test->request( GET '/empty' );

    is( $response->code, 200, 'an empty view is not an error' );
    is( $response->content, '', 'and renders as nothing' );
};

subtest 'having no content source at all does raise' => sub {
    # The guard at Role/Template.pm:239 fires when there is nothing to render:
    # no view, and no 'content' passed in the options. Checked against the
    # engine directly, because reaching it through a request would only show
    # the 500 it turns into.
    my $engine = Dancer2::Template::TemplateToolkit->new(
        views      => $VIEWS->stringify,
        layout_dir => 'layouts',
        config     => {},
    );

    my $err = exception { $engine->process( undef, {}, {} ) };
    ok( defined $err, 'processing with no view and no content throws' );
    like( $err, qr/Template did not produce any content/,
        'with the message that names the problem' );

    # The contrast that makes the above meaningful: an empty view is *not*
    # this case, and must not throw.
    is( exception { $engine->process( 'empty', {}, {} ) }, undef,
        'an empty view is a different case and does not throw' );
    is( $engine->process( 'empty', {}, {} ), '',
        'it returns the empty string' );
};

done_testing();
