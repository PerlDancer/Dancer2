use strict;
use warnings;
use Dancer2;
use Test::More ();

my @routes = get '/' => sub {1};
Test::More::is( scalar @routes, 2, 'Two routes available' );
foreach my $route (@routes) {
    Test::More::isa_ok( $route, 'Dancer2::Core::Route' );
}

Test::More::is( $routes[0]->method, 'get', 'Created GET route' );
Test::More::is( $routes[1]->method, 'head', 'Created HEAD route too' );

Test::More::done_testing;
