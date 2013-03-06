# who test the tester? We do!

use strict;
use warnings;

use Test::More tests => 45;

use Dancer2 ':syntax';
use Dancer2::Test;
use Dancer2::Core::Request;

my @routes = (
    '/foo',
    [GET => '/foo'],
    Dancer2::Core::Request->new(
        path   => '/foo',
        method => 'GET',
    ),
    Dancer2::Core::Response->new(
        content => 'fighter',
        status  => 404,
    )
);

route_doesnt_exist $_ for @routes;

get '/foo' => sub {'fighter'};
$routes[-1]->status(200);

route_exists $_, "route $_ exists" for @routes;

for (@routes) {
    my $response = dancer_response $_;
    isa_ok $response      => 'Dancer2::Core::Response';
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

response_headers_include $_ => [Server => "Perl Dancer2 $Dancer2::VERSION"]
  for @routes;

## Check parameters get through ok
get '/param' => sub { param('test') };
my $param_response = dancer_response(GET => '/param', { params => { test => 'hello' } });
is $param_response->content, 'hello', 'PARAMS get echoed by route';
