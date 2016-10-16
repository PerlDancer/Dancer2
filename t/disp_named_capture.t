use warnings;
use strict;

use Plack::Test;
use HTTP::Request;
use Test::More tests => 2;

{
    package app;
    use Dancer2;
    get '/1' => sub {
        return '1';
    };
    get '/2' => sub {
        return '2';
    };
}

my $test = Plack::Test->create( app->to_app );
my $request  = HTTP::Request->new( GET => 'http://localhost/1' );
my $response = $test->request( $request );
is( $response->content, 1 );

# "Dummy" regex to populate global $+
# eval'd as named captures are not available until 5.10
my $c;
eval <<'NAMED';
"12345" =~ m#(?<capture>23)#;
$c = $+{capture};
NAMED

$request  = HTTP::Request->new( GET => 'http://localhost/2' );
$response = $test->request( $request );
is( $response->content, 2 );

