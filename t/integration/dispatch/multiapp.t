use strict;
use warnings;

use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

# Multi-app dispatch only happens through the runner's psgi_app -- to_app is a
# single application's PSGI sub and knows nothing about its neighbours. Every
# test below therefore builds its app list with Dancer2->psgi_app([...]), which
# also pins the dispatch *order* to the order given rather than to whatever
# order the packages happened to be compiled in.
#
# 'logger => null' keeps the suite quiet; these tests assert on responses.

{
    package MultiFirst;
    use Dancer2;
    set logger  => 'null';
    set session => 'Simple';

    get '/first-only' => sub { 'FIRST' };

    # Both applications declare these two paths. The first app in the list
    # should answer them, and the second app's version should never run.
    get '/shared/status' => sub { status 404; 'FIRST-SET-404' };
    get '/shared/error'  => sub { send_error 'first says gone' => 404 };
    get '/shared/ok'     => sub { 'FIRST-OK' };

    get '/to-second' => sub {
        session who => 'set-in-first';
        forward '/second-only';
    };

    get '/landing' => sub {
        'LANDED-IN-FIRST who=' . ( session('who') // 'undef' );
    };
}

{
    package MultiSecond;
    use Dancer2;
    set logger  => 'null';
    set session => 'Simple';

    get '/second-only' => sub {
        'SECOND who=' . ( session('who') // 'undef' );
    };

    get '/shared/status' => sub { 'SECOND-SHOULD-NOT-RUN' };
    get '/shared/error'  => sub { 'SECOND-SHOULD-NOT-RUN' };
    get '/shared/ok'     => sub { 'SECOND-OK' };

    get '/to-first' => sub {
        session who => 'set-in-second';
        forward '/landing';
    };
}

{
    package MultiUri;
    use Dancer2;
    set logger => 'null';

    get 'item'      => '/item/:id'      => sub { 'item' };
    get 'two_parts' => '/a/:one/b/:two' => sub { 'two parts' };
    get 'by_regex'  => qr{^/re/(\d+)$}  => sub { 'regex' };

    # uri_for_route dies on bad input, and a die inside a route would be
    # swallowed into a 500 page. Each generating route therefore reports
    # whether it lived and with what, so the test can assert on the outcome
    # rather than on the shape of an error page.
    sub _try {
        my $code   = shift;
        my $result = eval { $code->() };
        return defined $result ? "LIVED $result" : "DIED $@";
    }

    get '/uri/ok'      => sub { _try( sub { uri_for_route( 'item', { id => 7 } ) } ) };
    get '/uri/zero'    => sub { _try( sub { uri_for_route( 'item', { id => 0 } ) } ) };
    get '/uri/empty'   => sub { _try( sub { uri_for_route( 'item', { id => '' } ) } ) };
    get '/uri/missing' => sub { _try( sub { uri_for_route('item') } ) };
    get '/uri/partial' => sub { _try( sub { uri_for_route( 'two_parts', { one => 'x' } ) } ) };
    get '/uri/regex'   => sub { _try( sub { uri_for_route( 'by_regex', { x => 1 } ) } ) };
    get '/uri/plain'   => sub { _try( sub { uri_for('/item/7') } ) };
}

sub multi_app { Plack::Test->create( Dancer2->psgi_app( [@_] ) ) }

subtest 'a request the first app cannot match is offered to the next one' => sub {
    my $test = multi_app(qw< MultiFirst MultiSecond >);

    is( $test->request( GET '/first-only' )->content, 'FIRST',
        'the first app answers a path only it declares' );

    my $res = $test->request( GET '/second-only' );
    is( $res->code, 200, 'a path only the second app declares is still served' );
    is( $res->content, 'SECOND who=undef',
        'the second app answered it, not a 404 from the first' );
};

subtest 'a path no app declares gets one 404 from the first app' => sub {
    my $test = multi_app(qw< MultiFirst MultiSecond >);

    my $res = $test->request( GET '/declared/nowhere' );
    is( $res->code, 404, 'exhausting every app produces a 404' );
    like( $res->header('Content-Type'), qr{^text/html},
        'it is the rendered error page, not a bare PSGI triplet' );
    like( $res->content, qr{/declared/nowhere},
        'the error page names the path that was not found' );
};

subtest 'a deliberate 404 from the first app is not treated as "no match"' => sub {
    my $test = multi_app(qw< MultiFirst MultiSecond >);

    # The distinction this subtest exists for: "no route matched" makes the
    # dispatcher try the next app, but a route that matched and *chose* 404
    # must end the request. Both apps declare these paths, so if the
    # distinction collapses the second app's 200 leaks out in place of the 404.
    my $status = $test->request( GET '/shared/status' );
    is( $status->code, 404, 'the status the matched route set is kept' );
    is( $status->content, 'FIRST-SET-404',
        'the first app\'s body is returned' );
    unlike( $status->content, qr/SECOND/,
        'the second app was never consulted' );

    my $error = $test->request( GET '/shared/error' );
    is( $error->code, 404, 'send_error in a matched route also ends the request' );
    unlike( $error->content, qr/SECOND/,
        'the second app was not consulted for send_error either' );

    is( $test->request( GET '/shared/ok' )->content, 'FIRST-OK',
        'and an ordinary shared path is answered by the first app' );
};

subtest 'apps are consulted in the order they were listed' => sub {
    # Same two apps, opposite order. This is what makes the subtest above a
    # statement about matching rather than about which package loaded first.
    my $test = multi_app(qw< MultiSecond MultiFirst >);

    is( $test->request( GET '/shared/ok' )->content, 'SECOND-OK',
        'the app listed first answers a path both declare' );
    is( $test->request( GET '/first-only' )->content, 'FIRST',
        'the app listed second still gets what only it declares' );
};

subtest 'a forward across apps keeps the session' => sub {
    my $test = multi_app(qw< MultiFirst MultiSecond >);

    is(
        $test->request( GET '/to-second' )->content,
        'SECOND who=set-in-first',
        'a session created in the first app is visible after forwarding to the second',
    );

    # The reverse direction re-enters an app earlier in the list, which is a
    # different path through the dispatch loop.
    is(
        $test->request( GET '/to-first' )->content,
        'LANDED-IN-FIRST who=set-in-second',
        'and a session created in the second app survives a forward back to the first',
    );
};

subtest 'uri_for_route refuses rather than emitting an unsubstituted token' => sub {
    my $test = multi_app('MultiUri');

    is( $test->request( GET '/uri/ok' )->content,
        'LIVED http://localhost/item/7',
        'a supplied route parameter is substituted' );

    for my $case (
        [ '/uri/missing', qr/uses the parameter 'id', which was not provided/,
            'a route parameter with no value at all is refused' ],
        [ '/uri/partial', qr/uses the parameter 'two', which was not provided/,
            'supplying only some of the parameters is refused too' ],
    ) {
        my ( $path, $expected, $name ) = @$case;
        my $content = $test->request( GET $path )->content;
        like( $content, qr/^DIED/, "$name (it dies)" );
        like( $content, $expected, $name );
        unlike( $content, qr/:(?:id|two)/,
            'no URL containing an unsubstituted :token is produced' );
    }
};

subtest 'uri_for_route accepts a route parameter of 0, but not undef or ""' => sub {
    my $test = multi_app('MultiUri');

    # Fixed behavior: the parameter is tested for definedness rather than
    # for truth, so 0 -- an ordinary database ID, list index or page number
    # -- is substituted like any other value. Previously the check was for
    # truth, so a 0 was refused as though it had not been given at all.
    is( $test->request( GET '/uri/zero' )->content,
        'LIVED http://localhost/item/0',
        'a route parameter of 0 is substituted, not rejected' );

    # The empty string is a different case from 0, and is still refused:
    # ':id' compiles to ([^/]+), which matches at least one character, so
    # substituting '' would yield '/item/' -- a URI that cannot match the
    # route it was generated from. Refusing beats handing back a URL that
    # 404s against its own application.
    my $empty = $test->request( GET '/uri/empty' )->content;
    like( $empty, qr/^DIED/, 'an empty route parameter is refused' );
    like( $empty, qr/was given an empty value for the parameter 'id'/,
        'and says the value was empty rather than missing' );
    unlike( $empty, qr/which was not provided/,
        'not reusing the "not provided" wording for a value that was provided' );

    # A parameter that was genuinely never supplied must still die, with the
    # same message as before, and must be distinguishable from the empty
    # case above -- that distinction is the point of the two messages.
    my $content = $test->request( GET '/uri/missing' )->content;
    like( $content, qr/^DIED/, 'a route parameter with no value at all is still refused' );
    like( $content, qr/uses the parameter 'id', which was not provided/,
        'with the existing message' );
};

subtest 'uri_for_route refuses a regex route instead of guessing' => sub {
    my $test = multi_app('MultiUri');

    my $content = $test->request( GET '/uri/regex' )->content;
    like( $content, qr/^DIED/, 'a named regex route cannot be turned into a URL' );
    like( $content, qr/does not support regexp route paths/,
        'and says so, rather than producing a URL built from the pattern' );
};

subtest 'a mounted app keeps its mount path in generated URLs' => sub {
    my $psgi   = Dancer2->psgi_app( [qw< MultiFirst MultiSecond MultiUri >] );
    my $test   = Plack::Test->create( builder { mount '/sub' => $psgi } );
    my $prefix = 'http://localhost/sub';

    is( $test->request( GET "$prefix/second-only" )->code, 200,
        'dispatch still reaches every app under a mount path' );

    is( $test->request( GET "$prefix/uri/plain" )->content,
        "LIVED $prefix/item/7",
        'uri_for includes the mount path' );

    is( $test->request( GET "$prefix/uri/ok" )->content,
        "LIVED $prefix/item/7",
        'uri_for_route includes the mount path' );
};

done_testing();
