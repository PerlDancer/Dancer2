use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;
use Path::Tiny ();

# The AutoPage handler serves any request whose path matches an existing view,
# with no route declared for it. It is off by default and switched on with
# 'auto_page: 1'.
#
# Because it turns the request path into a view path, it needs a carve-out so
# that layout templates are not served as pages, and it has one:
# Dancer2/Handler/AutoPage.pm:36-40 passes the request on when the path starts
# with the layout directory. That guard is what the last subtest here probes.
#
# auto_page has to come from a config file rather than 'set', because
# route_handlers - which is what registers this handler - is read once when the
# application object is constructed at import time.

my ( $DIR, $VIEWS, $CASE_INSENSITIVE_FS );

BEGIN {
    $DIR   = Path::Tiny->tempdir;
    $VIEWS = $DIR->child('views');
    $VIEWS->child('layouts')->mkpath;
    $VIEWS->child('sub')->mkpath;
    $DIR->child('conf')->mkpath;

    $VIEWS->child('autopage.tt')->spew_utf8('AUTO-PAGE-CONTENT');
    $VIEWS->child('shadowed.tt')->spew_utf8('VIEW-CONTENT');
    $VIEWS->child( 'sub', 'deep.tt' )->spew_utf8('DEEP-CONTENT');
    $VIEWS->child( 'layouts', 'main.tt' )->spew_utf8('MAIN{[% content %]}');

    # Does this filesystem resolve a differently-cased path to the same file?
    # macOS and Windows normally do; most Linux filesystems do not. The last
    # subtest is only meaningful where it does, so ask rather than assume.
    $CASE_INSENSITIVE_FS = -f $VIEWS->child( 'Layouts', 'main.tt' )->stringify;

    $DIR->child( 'conf', 'config.yml' )->spew_utf8( <<"YML" );
auto_page: 1
layout: main
views: "@{[ $VIEWS->stringify ]}"
template: template_toolkit
logger: "null"
YML
}

BEGIN { $ENV{DANCER_CONFDIR} = $DIR->child('conf')->stringify }

{
    package AutoPageApp;
    use Dancer2;

    # A declared route, to check it takes precedence over a view of the
    # same name.
    get '/shadowed' => sub { 'ROUTE-CONTENT' };
}

BEGIN { delete $ENV{DANCER_CONFDIR} }

my $test = Plack::Test->create( AutoPageApp->to_app );

sub get_path {
    my $path = shift;
    return $test->request( HTTP::Request->new( GET => $path ) );
}

subtest 'a request matching a view is served without a route' => sub {
    my $response = get_path('/autopage');

    is( $response->code, 200, 'the page is served' );
    is( $response->content, 'MAIN{AUTO-PAGE-CONTENT}',
        'rendered through the configured layout' );

    my $nested = get_path('/sub/deep');
    is( $nested->code, 200, 'a nested view is served too' );
    is( $nested->content, 'MAIN{DEEP-CONTENT}', 'also with the layout' );
};

subtest 'a request matching no view passes on' => sub {
    my $response = get_path('/no-such-page');

    # The handler passes rather than answering, so this reaches the
    # application's own 404 instead of an empty 200.
    is( $response->code, 404, 'a path with no matching view 404s' );
};

subtest 'a declared route wins over a view of the same name' => sub {
    my $response = get_path('/shadowed');

    is( $response->code, 200, 'the request is served' );
    is( $response->content, 'ROUTE-CONTENT',
        'by the declared route, not the view' );
    unlike( $response->content, qr/VIEW-CONTENT/,
        'the view is not used' );
};

subtest 'a layout cannot be requested as a page' => sub {
    my $response = get_path('/layouts/main');

    # The guard passes the request on, so it 404s like any unmatched path.
    is( $response->code, 404,
        'a path under the layout directory is refused' );
    unlike( $response->content, qr/MAIN\{/,
        'and the layout template is not rendered as a page' );

    # Paths that try to reach the layout directory indirectly are also
    # refused - here because the view lookup itself does not resolve them.
    for my $path ( '/x/../layouts/main', '/./layouts/main', '/sub/../layouts/main' ) {
        is( get_path($path)->code, 404, "$path is refused too" );
    }
};

subtest 'the layout guard holds under a different case' => sub {

    # This used to be reachable: the guard compared the request path
    # against the layout directory name with a case-sensitive match
    # (Dancer2/Handler/AutoPage.pm:38), so on a case-insensitive filesystem -
    # macOS and Windows by default - a request for /Layouts/main missed the
    # guard but still resolved to the same file, serving the layout template
    # as a page.
    #
    # The fix decides from the resolved file rather than the request path's
    # spelling (the same containment approach send_file uses:
    # $dir->realpath->subsumes($file_path)), so it closes the gap regardless
    # of the filesystem's case sensitivity. On a case-sensitive filesystem the
    # differently-cased request never reached the same file to begin with, so
    # it already 404s there for the unrelated reason that the view lookup
    # simply misses - the assertion below is meaningful on both kinds of
    # filesystem, just for different underlying reasons, which is why it no
    # longer needs the SKIP block the old bug-pinning version used.
    #
    # $CASE_INSENSITIVE_FS (computed in the BEGIN block above) is kept and
    # reported here so a failure can be told apart: on a case-insensitive
    # filesystem a regression would mean the containment check stopped
    # working; on a case-sensitive one it would mean the view lookup started
    # resolving differently-cased paths, which would be a different problem.
    note( 'this filesystem is ',
        ( $CASE_INSENSITIVE_FS ? 'case-insensitive' : 'case-sensitive' ),
        ' - the 404 below is reached ',
        ( $CASE_INSENSITIVE_FS
            ? 'via the containment check (the case the fix was about)'
            : 'because the view lookup itself already misses' ),
    );

    # The control: the correctly-cased path is refused.
    is( get_path('/layouts/main')->code, 404,
        'the correctly-cased layout path is refused' );

    my $response = get_path('/Layouts/main');
    is( $response->code, 404,
        'the same layout under a different case is refused too' );
    unlike( $response->content, qr/MAIN\{/,
        'and the layout template is not rendered as a page' );
};

done_testing();
