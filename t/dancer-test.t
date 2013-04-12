# who test the tester? We do!

use strict;
use warnings;

use Test::More tests => 48;

use Dancer2 ':syntax';
use Dancer2::Test;
use Dancer2::Core::Request;
use File::Temp;

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

post '/upload' => sub { 
    my $file = upload('test');
    return $file->content;
};
## Check we can upload files
my $file_response = dancer_response(POST => '/upload', {
    files => [{ filename => 'test.txt', name => 'test', data => 'testdata' }] } );
is $file_response->content, 'testdata', 'file uploaded with supplied data';

my $temp = File::Temp->new;
print $temp 'testfile';
close($temp);

$file_response = dancer_response(POST => '/upload', {
    files => [{ filename => $temp->filename, name => 'test' }] } );
is $file_response->content, 'testfile', 'file uploaded with supplied filename';

## Check multiselect/multi parameters get through ok
get '/multi' => sub {
    my $t = param('test');
    return join('', @$t) if ref($t) eq 'ARRAY';
    return 'bad';
};
$param_response = dancer_response(GET => '/multi', {
    params => { test => ['foo', 'bar'] } });
is $param_response->content, 'foobar',
    'multi values for same key get echoed back';
