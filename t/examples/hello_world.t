use strict;
use warnings;

use FindBin ();

use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common qw(GET);

my $app = do "$FindBin::Bin/../../examples/single/hello_world.psgi";
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);

my $res  = $test->request( GET '/' );
ok( $res->is_success, '[GET /] successful' );
is( $res->content, 'Hello World', 'Content looks ok' );

