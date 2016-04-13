use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer2::Core::Request;
use Dancer2::Core::Route;
use Capture::Tiny 0.12 'capture_stderr';

my @tests = (
    [   [ 'get', '/', sub {11} ], '/', [ {}, 11 ] ],
    [   [ 'get', '/', sub {11} ],
        '/failure',
        [ undef, 11 ]
    ],

    # token tests
    [   [ 'get', '/hello/:name', sub {22} ],
        '/hello/sukria',
        [ { name => 'sukria' }, 22 ]
    ],
    [   [ 'get', '/hello/:name?', sub {22} ],
        '/hello/',
        [ { name => undef }, 22 ]
    ],

    # prefix tests
    [   [ 'get', '/', sub {33}, '/forum' ],
        '/forum/',
        [ {}, 33 ]
    ],
    [   [ 'get', '/', sub {33}, '/forum' ],
        '/forum/',
        [ {}, 33 ]
    ],
    [   [ 'get', '/mywebsite', sub {33}, '/forum' ],
        '/forum/mywebsite',
        [ {}, 33 ]
    ],
    [   [ 'get', '', sub {'concat'}, '/' ],
        '/',
        [ {}, 'concat' ]
    ],

    # token in prefix tests
    [   [ 'get', 'name', sub {35}, '/hello/:' ],
        '/hello/sukria',
        [ { name => 'sukria' }, 35 ],
    ],

    [   [ 'get', '/', sub {36}, '/hello/:name' ],
        '/hello/sukria/',
        [ { name => 'sukria' }, 36 ],
    ],

    # splat test
    [   [ 'get', '/file/*.*', sub {44} ],
        '/file/dist.ini',
        [ { splat => [ 'dist', 'ini' ] }, 44 ]
    ],

    # splat in prefix
    [   [ 'get', '', sub {42}, '/forum/*'],
        '/forum/dancer',
        [ { splat => [ 'dancer' ] }, 42 ]
    ],

    # megasplat test
    [   [ 'get', '/file/**/*', sub {44} ],
        '/file/some/where/42',
        [ { splat => [ [ 'some', 'where' ], '42' ] }, 44 ]
    ],

    # megasplat consistently handles multiple slashes
    [   [ 'get', '/foo/**', sub {'45a'} ],
        '/foo/bar///baz',
        [ { splat => [ [ 'bar', '', '', 'baz' ] ] }, '45a' ]
    ],
    [   [ 'get', '/foo/**', sub {'45b'} ],
        '/foo/bar///',  # empty trailing path segment
        [ { splat => [ [ 'bar', '', '', '' ] ] }, '45b' ]
    ],

    # Optional megasplat test - with a value...
    [   [ 'get', '/foo/?**?', sub {46} ],
        '/foo/bar/baz',
        [ { splat => [ [ 'bar', 'baz' ] ] }, 46 ],
    ],
    # ... and without
    [   [ 'get', '/foo/?**?', sub {47} ],
        '/foo',
        [ { splat => [ [ ] ] }, 47 ],
    ],

    # mixed (mega)splat and tokens
    [   [ 'get', '/some/:id/**/*', sub {55} ],
        '/some/where/to/run/and/hide',
        [ { id => 'where', splat => [ [ 'to', 'run', 'and' ], 'hide' ] }, 55 ]
    ],
    [   [ 'get', '/some/*/**/:id?', sub {55} ],
        '/some/one/to/say/boo/',
        [ { id => undef, splat => [ 'one', [ 'to', 'say', 'boo' ] ] }, 55 ]
    ],

    # supplied regex
    [   [ 'get', qr{stuff(\d+)}, sub {44} ], '/stuff48',
        [ { splat => [48] }, 44 ]
    ],
    [   [ 'get', qr{/stuff(\d+)}, sub {44}, '/foo' ],
        '/foo/stuff48',
        [ { splat => [48] }, 44 ],
    ],
);


plan tests => 110;

for my $t (@tests) {
    my ( $route, $path, $expected ) = @$t;

    if ( ref($expected) eq 'Regexp' ) {
        like(
            exception {
                my $r = Dancer2::Core::Route->new(
                    method => $route->[0],
                    regexp => $route->[1],
                    code   => $route->[2],
                    prefix => $route->[3],
                );
            },
            $expected,
            "got expected exception for $path",
        );
    }
    else {
        my $r = Dancer2::Core::Route->new(
            method => $route->[0],
            regexp => $route->[1],
            code   => $route->[2],
            prefix => $route->[3],
        );
        isa_ok $r, 'Dancer2::Core::Route';

        my $request = Dancer2::Core::Request->new(
            env => {
                PATH_INFO      => $path,
                REQUEST_METHOD => $route->[0],
            }
        );
        my $m;
        is( capture_stderr { $m = $r->match($request) }, '',
            "no warnings generated for $path" );
        is_deeply $m, $expected->[0], "got expected data for '$path'";

        {
            package App; use Dancer2; ## no critic
        }

        use Dancer2::Core::App;
        use Dancer2::Core::Response;
        my $app = Dancer2::Core::App->new(
            request  => $request,
            response => Dancer2::Core::Response->new,
        );

        is $r->execute($app)->content, $expected->[1], "got expected result for '$path'";

        # failing request
        my $failing_request = Dancer2::Core::Request->new(
            env => {
                PATH_INFO      => '/something_that_doesnt_exist',
                REQUEST_METHOD => 'GET',
            },
        );

        $m = $r->match($failing_request);
        is $m, undef, "don't match failing request";
    }
}

# captures test
SKIP: {
    skip "Need perl >= 5.10", 1 unless $] >= 5.010;

    ## Regexp is parsed in compile time. So, eval with QUOTES to force to parse later.
    my $route_regex;

    ## no critic

    eval q{
    $route_regex = qr{/(?<class> user | content | post )/(?<action> delete | find )/(?<id> \d+ )}x;
      };

    ## use critic

    my $r = Dancer2::Core::Route->new(
        regexp => $route_regex,
        code   => sub {
            'ok';
        },
        method => 'get',
    );

    my $request = Dancer2::Core::Request->new(
        env => {
            PATH_INFO      => '/user/delete/234',
            REQUEST_METHOD => 'GET',
        },
    );

    my $m = $r->match($request);

    is_deeply $m,
      { captures => {
            class  => 'user',
            action => 'delete',
            id     => 234
        }
      },
      "named captures work";
}

note "routes with options"; {
    my $route_w_options = Dancer2::Core::Route->new(
        method  => 'get',
        regexp  => '/',
        code    => sub {'options'},
        options => { 'agent' => 'cURL' },
    );

    my $req = Dancer2::Core::Request->new(
        path   => '/',
        method => 'get',
        env    => { 'HTTP_USER_AGENT' => 'mozilla' },
    );

    my $m = $route_w_options->match($req);
    ok !defined $m, 'Route did not match';

    $req = Dancer2::Core::Request->new(
        path   => '/',
        method => 'get',
        env    => { 'HTTP_USER_AGENT' => 'cURL' },
    );

    $m = $route_w_options->match($req);
    ok defined $m, 'Route matched';

    $route_w_options = Dancer2::Core::Route->new(
        method  => 'get',
        regexp  => '/',
        code    => sub {'options'},
        options => {
            'agent' => 'cURL',
            'content_type' => 'foo',
        },
    );

    $req = Dancer2::Core::Request->new(
        path   => '/',
        method => 'get',
        env    => { 'HTTP_USER_AGENT' => 'cURL' },
    );

    # Check match more than once (each iterator wasn't reset, for loop is ok )
    $m = $route_w_options->match($req);
    ok !defined $m, 'More options - Route did not match - test 1';
    $m = $route_w_options->match($req);
    ok !defined $m, 'More options - Route did not match - test 2';
}
