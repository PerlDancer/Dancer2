use strict;
use warnings;

use Test::More tests => 9;
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
};

