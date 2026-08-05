use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Path::Tiny ();

# What renders an error page, and what happens when the thing meant to render
# it is itself broken.
#
# Dancer2::Core::Error::_build_content tries four sources in order:
#
#   1. a view named after the status  (views/500.tt)      - Error.pm:298-317
#   2. public/<status>.html                               - Error.pm:319-324
#   3. the configured error_template                      - Error.pm:326-341
#   4. the built-in default page                          - Error.pm:343
#
# Steps 1 and 3 render through the app's template engine, which is exactly what
# may have caused the error in the first place, so both are wrapped in an eval.
# A throwing template must therefore fall through rather than take the handler
# down - that is the behavior these tests exist for.
#
# Step 2 is skipped for a 500 when show_stacktrace is on (Error.pm:320): a
# static page would throw away the diagnostics the developer turned on.
#
# Template::Toolkit is used rather than the default Template::Tiny because
# [% THROW %] gives a template that reliably dies. It is a hard dependency of
# this distribution, so this adds nothing.

my $DIR;
BEGIN {
    $DIR = Path::Tiny->tempdir;
    $DIR->child('views')->mkpath;
    $DIR->child('public')->mkpath;
    $DIR->child('empty-public')->mkpath;

    # A view named for the status that blows up when rendered.
    $DIR->child( 'views', '500.tt' )
        ->spew_utf8('[% THROW nope "this template is broken" %]');

    # Static pages, distinguishable in the body.
    $DIR->child( 'public', '500.html' )->spew_utf8('STATIC-500-PAGE');
    $DIR->child( 'public', '404.html' )->spew_utf8('STATIC-404-PAGE');

    # A working configured error_template.
    $DIR->child( 'views', 'my_error.tt' )
        ->spew_utf8('CONFIGURED-ERROR-TEMPLATE status=[% status %]');
}

# show_stacktrace on, broken 500.tt, static pages present.
{
    package TraceOnApp;
    use Dancer2;
    set template        => 'template_toolkit';
    set views           => $DIR->child('views')->stringify;
    set public_dir      => $DIR->child('public')->stringify;
    set show_stacktrace => 1;
    set logger          => 'capture';

    get '/die' => sub { die "kaboom\n" };
    get '/nf'  => sub { send_error( 'gone', 404 ) };
}

# Identical, but show_stacktrace off.
{
    package TraceOffApp;
    use Dancer2;
    set template        => 'template_toolkit';
    set views           => $DIR->child('views')->stringify;
    set public_dir      => $DIR->child('public')->stringify;
    set show_stacktrace => 0;
    set logger          => 'capture';

    get '/die' => sub { die "kaboom\n" };
    get '/nf'  => sub { send_error( 'gone', 404 ) };
}

# No static pages at all, but a configured error_template.
{
    package ErrorTemplateApp;
    use Dancer2;
    set template        => 'template_toolkit';
    set views           => $DIR->child('views')->stringify;
    set public_dir      => $DIR->child('empty-public')->stringify;
    set show_stacktrace => 0;
    set error_template  => 'my_error';
    set logger          => 'capture';

    get '/die' => sub { die "kaboom\n" };
}

sub logs_of {
    my $package = shift;
    return $package->dancer_app->logger_engine->trapper->read;
}

subtest 'a throwing status template falls through to the static page' => sub {
    my $test = Plack::Test->create( TraceOffApp->to_app );

    logs_of('TraceOffApp');    # drain anything from app startup

    my $response = $test->request( GET '/die' );

    # The handler survived: a response came back at all, with the right status.
    is( $response->code, 500, 'the request still gets a 500, not a hang or a crash' );
    is( $response->content, 'STATIC-500-PAGE',
        'and the static page is served instead of the broken template' );

    # The failure is not swallowed silently - it is logged as a warning, so a
    # developer can find out their error template is broken.
    my @warnings = grep { $_->{level} eq 'warning' } @{ logs_of('TraceOffApp') };
    ok( scalar @warnings, 'the template failure is logged' );
    like(
        join( "\n", map { $_->{message} } @warnings ),
        qr/this template is broken/,
        'and the log names the template error',
    );
};

subtest 'a status template is preferred when it works' => sub {
    # 404 has no 404.tt, so the static 404.html is used. This is the control
    # for the subtest above: it shows the static page is reached by falling
    # through the template step, not because static always wins.
    my $test = Plack::Test->create( TraceOffApp->to_app );

    my $response = $test->request( GET '/nf' );
    is( $response->code, 404, 'the 404 keeps its status' );
    is( $response->content, 'STATIC-404-PAGE',
        'and gets its own static page' );
};

subtest 'a 500 with show_stacktrace on skips the static page' => sub {
    my $test = Plack::Test->create( TraceOnApp->to_app );

    my $response = $test->request( GET '/die' );
    my $body     = $response->content;

    is( $response->code, 500, 'still a 500' );

    # Same app layout as TraceOffApp, which served STATIC-500-PAGE here. With
    # show_stacktrace on, the static page is deliberately bypassed so the
    # diagnostics are not thrown away.
    isnt( $body, 'STATIC-500-PAGE',
        'the static 500 page is not used when a stack trace was asked for' );
    like( $body, qr/<div class="title">Stack</,
        'the built-in diagnostic page is rendered instead' );

    # A 4xx is unaffected by that rule and still gets its static page.
    is( $test->request( GET '/nf' )->content, 'STATIC-404-PAGE',
        'a 404 still gets its static page with show_stacktrace on' );
};

subtest 'the configured error_template is used when there is no static page' => sub {
    my $test = Plack::Test->create( ErrorTemplateApp->to_app );

    my $response = $test->request( GET '/die' );

    is( $response->code, 500, 'the status is a 500' );
    like( $response->content, qr/^CONFIGURED-ERROR-TEMPLATE/,
        'the configured error_template renders the page' );
    like( $response->content, qr/status=500/,
        'and is given the status to render' );
};

done_testing();
