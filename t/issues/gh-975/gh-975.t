use strict;
use warnings;
use Test::More 'tests' => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
}

my $test = Plack::Test->create( App->to_app );
my $res  = $test->request( GET '/test.txt' );
ok( $res->is_success, 'Succeeded retrieving file' );
like( $res->content, qr{^this is test\.txt}, 'Correct file content' );
