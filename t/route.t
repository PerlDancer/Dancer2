use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer2::Core::Route;

my @tests = (
    [['get', '/', sub {11}], '/', [{}, 11]],
    [['get', '/', sub {11}],
        '/failure',
        [undef, 11]
    ],

    [   ['get', '/hello/:name', sub {22}],
        '/hello/sukria',
        [{name => 'sukria'}, 22]
    ],

    [['get', '/', sub {33}, '/forum'], '/forum',  [{splat => [1]}, 33]],
    [['get', '/', sub {33}, '/forum'], '/forum/', [{splat => [1]}, 33]],
    [['get', '/mywebsite', sub {33}, '/forum'], '/forum/mywebsite', [{}, 33]],

    # splat test
    [   ['get', '/file/*.*', sub {44}],
        '/file/dist.ini',
        [{splat => ['dist', 'ini']}, 44]
    ],

    # megasplat test
    [   ['get', '/file/**/*', sub {44}],
        '/file/some/where/42',
        [{splat => [['some', 'where'], '42']}, 44]
    ],


    [['get', qr{stuff(\d+)}, sub {44}], '/stuff48', [{splat => [48]}, 44]],

    [   ['get', qr{stuff(\d+)}, sub {44}, '/foo'],
        '/foo/stuff48',
        qr {Cannot combine a prefix \(/foo\) with a regular expression},
    ],
);

plan tests => 38;

for my $t (@tests) {
    my ($route, $path, $expected) = @$t;

    if (ref($expected) eq 'Regexp') {
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

        my $m = $r->match($route->[0] => $path);
        is_deeply $m, $expected->[0], "got expected data for '$path'";
        is $r->execute, $expected->[1], "got expected result for '$path'";

        # failing request
        $m = $r->match(get => '/something_that_doesnt_exist');
        is $m, undef, "dont match failing request";
    }
}

# captures test
SKIP: {
    skip "Need perl >= 5.10", 1 unless $] >= 5.010;

    my $route_regex =
      qr{/(?<class> user | content | post )/(?<action> delete | find )/(?<id> \d+ )}x;

    my $r = Dancer2::Core::Route->new(
        regexp => $route_regex,
        code   => sub {
            'ok';
        },
        method => 'get',
    );

    my $m = $r->match(get => '/user/delete/234');

    is_deeply $m,
      { captures => {
            class  => 'user',
            action => 'delete',
            id     => 234
        }
      },
      "named captures work";
}

