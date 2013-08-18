use strict;
use warnings;

use Test::More tests => 7;
use Dancer2::Serializer::Dumper;

{

    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    get '/json'    => sub { return { bar => 'baz' } };
    get '/to_json' => sub { to_json({bar => 'baz'}, {pretty => 1}) };
}

use Dancer2::Test apps => ['MyApp'];

# Response with implicit call to the serializer
my $resp = dancer_response('/json');
response_status_is $resp  => 200;
response_content_is $resp => '{"bar":"baz"}';
response_headers_include $resp, [ 'Content-Type' => 'application/json' ];

# Response with explicit call to the serializer
$resp = dancer_response('/to_json');
response_status_is $resp  => 200;
response_content_is $resp => "{\n   \"bar\" : \"baz\"\n}\n";
# When calling `to_json', the content_type is not set,
# because we can't assume we're calling it for a response
response_headers_include $resp,
    [ 'Content-Type' => 'text/html; charset=UTF-8' ];

my $serializer = Dancer2::Serializer::Dumper->new();
is $serializer->content_type, 'text/x-data-dumper', 'content-type is set correctly';
