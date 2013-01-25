# who test the tester? We do!

use strict;
use warnings;

use Test::More tests => 44;

use Dancer ':syntax';
use Dancer::Test;
use Dancer::Core::Request;

my @routes = (
    '/foo',
    [GET => '/foo'],
    Dancer::Core::Request->new(
        path   => '/foo',
        method => 'GET',
    ),
    Dancer::Core::Response->new(
        content => 'fighter',
        status  => 404,
    )
);

route_doesnt_exist $_ for @routes;

get '/foo' => sub {'fighter'};
$routes[-1]->status(200);

route_exists $_ for @routes;

for (@routes) {
    my $response = dancer_response $_;
    isa_ok $response      => 'Dancer::Core::Response';
    is $response->content => 'fighter';
}

response_content_is $_ => 'fighter', "response_content_is with $_" for @routes;
response_content_isnt $_ => 'platypus',
  "response_content_isnt with $_"
  for @routes;
response_content_like $_   => qr/igh/   for @routes;
response_content_unlike $_ => qr/ought/ for @routes;

response_status_is $_   => 200 for @routes;
response_status_isnt $_ => 203 for @routes;

response_headers_include $_ => [Server => "Perl Dancer $Dancer::VERSION"]
  for @routes;

