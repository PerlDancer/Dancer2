use strict;
use warnings;
use Test::More;


use Dancer::Core::Route;

my @tests = (
    [ ['get', '/', sub { 11 }], 
      '/', 
      [ {}, 11] 
    ],

    [ ['get', '/hello/:name', sub { 22 }], 
      '/hello/sukria', 
      [ {name => 'sukria'}, 22] 
    ],

    [ ['get', '/', sub { 33 }, '/forum'], 
      '/forum', 
      [ {splat => [1]}, 33] 
    ],
    [ ['get', '/', sub { 33 }, '/forum'], 
      '/forum/', 
      [ {splat => [1]}, 33] 
    ],

    [ ['get', '/file/*.*', sub { 44 }], 
      '/file/dist.ini', 
      [ {splat => ['dist', 'ini']}, 44] 
    ],

    [ ['get', qr{stuff(\d+)}, sub { 44 }], 
      '/stuff48', 
      [ {splat => [48]}, 44] 
    ],

# FIXME: does not pass yet, does it pass in Dancer?
#    [ ['get', qr{stuff(\d+)}, sub { 44 }, '/foo'], 
#      '/foo/stuff48', 
#      [ {splat => [48]}, 44] 
#    ],


);

plan tests => scalar(@tests) * 4;

for my $t (@tests) {
    my ($route, $path, $expected) = @$t;

    # successful request
    my $r = Dancer::Core::Route->new(
        method => $route->[0],
        regexp => $route->[1],
        code   => $route->[2],
        prefix => $route->[3],
    );

    note "regexp built: ".$r->regexp;
    isa_ok $r, 'Dancer::Core::Route';

    my $m = $r->match($route->[0] => $path);
    is_deeply $m, $expected->[0],
        "got expected data for '$path'";
    is $r->execute, $expected->[1],
        "got expected result for '$path'";

    # failing request
    $m = $r->match(get => '/something_that_doesnt_exist');
    is $m, undef, "dont match failing request";
}

done_testing;
