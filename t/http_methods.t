use strict;
use warnings;

use Test::More tests => 12;
use Plack::Test;
use HTTP::Request;

use Dancer2;

my %method = (
    get     => 'GET',
    post    => 'POST',
    del     => 'DELETE',
    patch   => 'PATCH',
    put     => 'PUT',
    options => 'OPTIONS',
);

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    while ( my ( $method, $http ) = each %method ) {
        eval "$method '/' => sub { '$method' }";
        is(
            $cb->( HTTP::Request->new( $http => '/' ) )->content,
            $method,
            "$http /",
        );
    }

    eval "get '/head' => sub {'HEAD'}";

    my $res = $cb->( HTTP::Request->new( HEAD => '/head' ) );
    is( $res->content, '', 'HEAD /' ); # HEAD requests have no content
    is( $res->headers->content_length, 4, 'Content-Length for HEAD' );

    # Testing invalid HTTP methods.
    {
        my $req = HTTP::Request->new( "ILLEGAL" => '/' );
        my $res = $cb->( $req );
        ok( !$res->is_success, "Response->is_success is false when using illegal HTTP method" );
        is( $res->code, 405, "Illegal method should return 405 code" );
        like( $res->content, qr<Method Not Allowed>, q<Illegal method should have "Method Not Allowed" in the content> );
    }
};
