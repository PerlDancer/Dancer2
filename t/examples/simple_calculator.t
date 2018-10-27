use strict;
use warnings;

use FindBin ();

use Test::More;
use Plack::Test;
use HTTP::Request::Common qw(GET POST);

my $app = do "$FindBin::Bin/../../examples/single/simple_calculator.psgi";
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);

my $res  = $test->request( GET '/' );
ok( $res->is_success, '[GET /] successful' );
like( $res->content, qr/powered by Dancer/, 'Content looks ok' );

subtest add  => sub {
    plan tests => 2;
    my $res  = $test->request( GET '/add/19/23' );
    ok( $res->is_success, '[GET /add/] successful' );
    is( $res->content, 42, 'Content looks ok' );
};

subtest multiply => sub {
    plan tests => 2;
    my $res  = $test->request( GET '/multiply?x=10&y=5' );
    ok( $res->is_success, '[GET /multiply/] successful' );
    is( $res->content, 50, 'Content looks ok' );
};

subtest division => sub {
    plan tests => 2;
    my $res = $test->request( POST '/division', { x=>10, y=>5 } );
    ok( $res->is_success, '[GET /division/] successful' );
    is( $res->content, 2, 'Content looks ok' );
};

done_testing();

