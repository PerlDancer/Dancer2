package app;
use Dancer2;
get '/1' => sub {
    return '1';
};
get '/2' => sub {
    return '2';
};
package main;
use Plack::Test;
use HTTP::Request;
use Test::More tests => 2;
my $test = Plack::Test->create( app->to_app );
my $request  = HTTP::Request->new( GET => 'http://localhost/1' );
my $response = $test->request( $request );
is( $response->content, 1 );
"12345" =~ m#(?<capture>23)#;
my $c = $+{capture};
$request  = HTTP::Request->new( GET => 'http://localhost/2' );
$response = $test->request( $request );
is( $response->content, 2 );

