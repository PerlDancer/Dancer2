use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer2::Core::Request;
use Dancer2::Core::Route;

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
        '/forum',
        [ { splat => [1] }, 33 ]
    ],
    [   [ 'get', '/', sub {33}, '/forum' ],
        '/forum/',
        [ { splat => [1] }, 33 ]
    ],
    [   [ 'get', '/mywebsite', sub {33}, '/forum' ],
        '/forum/mywebsite',
        [ {}, 33 ]
    ],

    # splat test
    [   [ 'get', '/file/*.*', sub {44} ],
        '/file/dist.ini',
        [ { splat => [ 'dist', 'ini' ] }, 44 ]
    ],

    # megasplat test
    [   [ 'get', '/file/**/*', sub {44} ],
        '/file/some/where/42',
        [ { splat => [ [ 'some', 'where' ], '42' ] }, 44 ]
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

plan tests => 55;

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
            env => {}, method => $route->[0], path => $path
        );
        my $m = $r->match($request);
        is_deeply $m, $expected->[0], "got expected data for '$path'";
        is $r->execute, $expected->[1], "got expected result for '$path'";

        # failing request
        my $failing_request = Dancer2::Core::Request->new(
            env    => {},
            method => 'get',
            path   => '/something_that_doesnt_exist',
        );
        $m = $r->match($failing_request);
        is $m, undef, "dont match failing request";
    }
}

# captures test
SKIP: {
    skip "Need perl >= 5.10", 1 unless $] >= 5.010;

    ## Regexp is parsed in compile time. So, eval with QUOTES to force to parse later.
    my $route_regex;

    eval q{
    $route_regex = qr{/(?<class> user | content | post )/(?<action> delete | find )/(?<id> \d+ )}x;
      };

    my $r = Dancer2::Core::Route->new(
        regexp => $route_regex,
        code   => sub {
            'ok';
        },
        method => 'get',
    );

    my $request = Dancer2::Core::Request->new(
        env    => {},
        method => 'get',
        path   => '/user/delete/234',
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

{
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
    ok !defined $m;

    $req = Dancer2::Core::Request->new(
        path   => '/',
        method => 'get',
        env    => { 'HTTP_USER_AGENT' => 'cURL' },
    );

    $m = $route_w_options->match($req);
    ok defined $m;
}
