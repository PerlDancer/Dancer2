use strict;
use warnings;

use Test::More tests => 6;

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

while (my ($method, $http) = each %method) {
    eval "$method '/' => sub { '$method' }";
    response_content_is [$http => '/'], $method, $method;
}
