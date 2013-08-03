use strict;
use warnings;

use Test::More tests => 4;
use Dancer2::Serializer::Dumper;

{

    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    get '/foo' => sub { return { bar => 'baz' } };
}

use Dancer2::Test apps => ['MyApp'];

my $resp = dancer_response('/foo');

response_status_is $resp => 200;

response_content_is $resp => '{"bar":"baz"}';

response_headers_include $resp, [ 'Content-Type' => 'application/json' ];

my $serializer = Dancer2::Serializer::Dumper->new();
is $serializer->content_type, 'text/x-data-dumper', 'content-type is set correctly';
