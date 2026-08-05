use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Dancer2::Core::Route;
use Dancer2::Core::Request;

# Build a request whose path is $path. Extra pairs are merged into the PSGI
# env, which is how we set headers (HTTP_USER_AGENT, CONTENT_TYPE, ...).
sub request_for {
    my ( $path, %env ) = @_;
    return Dancer2::Core::Request->new(
        env => {
            REQUEST_METHOD    => 'GET',
            PATH_INFO         => $path,
            'psgi.url_scheme' => 'http',
            HTTP_HOST         => 'localhost',
            %env,
        },
    );
}

sub route_for {
    return Dancer2::Core::Route->new( method => 'get', code => sub {1}, @_ );
}

# match() returns the captured data as a hashref on success (an empty hashref
# for a route with nothing to capture) and undef when the path doesn't match.
sub match_for {
    my ( $route, $path, %env ) = @_;
    return scalar $route->match( request_for( $path, %env ) );
}

subtest 'a static path matches itself and nothing else' => sub {
    my $route = route_for( regexp => '/about' );

    is_deeply( match_for( $route, '/about' ), {}, '/about matches, captures nothing' );
    is( match_for( $route, '/about/us' ), undef, '/about does not match /about/us' );
    is( match_for( $route, '/aboutus' ),  undef, '/about does not match /aboutus' );
};

subtest 'a leading slash is added when the pattern omits one' => sub {
    my $route = route_for( regexp => 'noslash' );

    is_deeply( match_for( $route, '/noslash' ), {},
        q{'noslash' is treated as '/noslash'} );
};

subtest 'a :token captures one path segment and stops at the slash' => sub {
    my $route = route_for( regexp => '/user/:id' );

    is_deeply( match_for( $route, '/user/42' ), { id => '42' },
        'the segment is captured under the token name' );

    # This is the assertion that fails if the token pattern ever becomes
    # greedy enough to swallow a '/'.
    is( match_for( $route, '/user/1/2' ), undef,
        'a token does not capture across a slash' );

    is( match_for( $route, '/user/' ), undef,
        'a token requires at least one character' );
    is( match_for( $route, '/user' ), undef, 'the segment is not optional' );
};

subtest 'a trailing ? makes a token optional' => sub {
    my $route = route_for( regexp => '/o/:id?' );

    is_deeply( match_for( $route, '/o/9' ), { id => '9' },
        'the token still captures when present' );
    is_deeply( match_for( $route, '/o/' ), { id => undef },
        'the token is undef when absent, and the route still matches' );
};

subtest 'a dot in the pattern is a literal dot, not a regex wildcard' => sub {
    my $route = route_for( regexp => '/file.txt' );

    is_deeply( match_for( $route, '/file.txt' ), {}, 'the literal path matches' );

    # This is the assertion that fails if '.' stops being escaped.
    is( match_for( $route, '/fileXtxt' ), undef,
        'the dot does not match an arbitrary character' );
};

subtest 'a * captures one segment into splat' => sub {
    my $route = route_for( regexp => '/a/*/b/*' );

    is_deeply(
        match_for( $route, '/a/one/b/two' ),
        { splat => [ 'one', 'two' ] },
        'each wildcard contributes one value, in order',
    );
    is( match_for( $route, '/a/one/two/b/three' ), undef,
        'a single wildcard does not span a slash' );
};

subtest 'a ** captures the rest of the path, split on slashes' => sub {
    my $route = route_for( regexp => '/files/**' );

    # The megasplat value is an arrayref *inside* splat: splat holds one entry
    # per wildcard, and this wildcard's entry is the list of segments.
    is_deeply(
        match_for( $route, '/files/a/b/c' ),
        { splat => [ [ 'a', 'b', 'c' ] ] },
        'the remaining path is split into segments',
    );
    is_deeply(
        match_for( $route, '/files/a' ),
        { splat => [ ['a'] ] },
        'a single segment still arrives as a one-element list',
    );
};

subtest 'a typed token rejects a value of the wrong type' => sub {
    my $route = route_for( regexp => '/n/:id[Int]' );

    is_deeply( match_for( $route, '/n/42' ), { id => '42' },
        'an integer is captured' );

    # This is the assertion that fails if the type check is dropped: without
    # it, '/n/abc' matches the same shape as '/n/42'.
    is( match_for( $route, '/n/abc' ), undef,
        'a non-integer does not match at all' );
};

subtest 'a prefix is prepended to the pattern' => sub {
    my $route = route_for( regexp => '/list', prefix => '/api' );

    is( $route->spec_route, '/api/list', 'spec_route records the prefixed path' );
    is_deeply( match_for( $route, '/api/list' ), {}, 'the prefixed path matches' );
    is( match_for( $route, '/list' ), undef, 'the unprefixed path does not' );
};

subtest 'a regexp route returns named captures under captures' => sub {
    my $route = route_for( regexp => qr{^/x/(?<who>\w+)$} );

    is_deeply(
        match_for( $route, '/x/bob' ),
        { captures => { who => 'bob' } },
        'named captures are grouped under the captures key',
    );
    is( match_for( $route, '/y/bob' ), undef, 'a non-matching path returns undef' );
};

subtest 'the deprecated placeholder names are refused at build time' => sub {
    like(
        exception { route_for( regexp => '/a/:splat' ) },
        qr/Named placeholder 'splat' is deprecated/,
        q{:splat dies rather than being silently accepted},
    );
    like(
        exception { route_for( regexp => '/a/:captures' ) },
        qr/Named placeholder 'captures' is deprecated/,
        q{:captures dies rather than being silently accepted},
    );
};

subtest 'an unrecognised matching option is refused at build time' => sub {
    like(
        exception { route_for( regexp => '/a', options => { bogus => 1 } ) },
        qr/Not a valid option for route matching: `bogus'/,
        'a typo in an option name dies instead of being ignored',
    );

    is(
        exception { route_for( regexp => '/a', options => { agent => 'x' } ) },
        undef,
        'a supported option name is accepted',
    );
};

subtest 'route options gate the match on request properties' => sub {
    my $route = route_for( regexp => '/only', options => { agent => 'Firefox' } );

    # The option value is used as a pattern, not compared for equality.
    is_deeply(
        match_for( $route, '/only', HTTP_USER_AGENT => 'Mozilla Firefox 3' ),
        {},
        'the option matches anywhere within the header value',
    );
    is( match_for( $route, '/only', HTTP_USER_AGENT => 'Chrome' ), undef,
        'a non-matching agent blocks the route' );
    is( match_for( $route, '/only' ), undef,
        'a missing agent header blocks the route' );

    my $typed = route_for(
        regexp  => '/ct',
        options => { content_type => 'application/json' },
    );
    is_deeply( match_for( $typed, '/ct', CONTENT_TYPE => 'application/json' ), {},
        'a matching content type is allowed through' );
    is( match_for( $typed, '/ct', CONTENT_TYPE => 'text/html' ), undef,
        'a non-matching content type blocks the route' );
};

done_testing();
