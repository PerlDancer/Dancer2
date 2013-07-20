use strict;
use warnings;

use Test::More tests => 8;

use Dancer2;
use Dancer2::Test;

my %method = (
    get     => 'GET',
    post    => 'POST',
    del     => 'DELETE',
    patch   => 'PATCH',
    put     => 'PUT',
    options => 'OPTIONS',
);

while ( my ( $method, $http ) = each %method ) {
    eval "$method '/' => sub { '$method' }";
    response_content_is [ $http => '/' ], $method, $method;
}

eval "get '/head' => sub {'HEAD'}";
my $resp = dancer_response( 'HEAD', '/head' );
is $resp->content, '', 'HEAD';
is $resp->header('Content-Length'), 4, 'Content-Length for HEAD';
