use strict;
use warnings;

use Test::More tests => 3;

{
    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    get '/foo' => sub { return { bar => 'baz' } };
}

use Dancer2::Test apps => [ 'MyApp' ];

my $resp = dancer_response( '/foo' );

response_status_is $resp => 200;

response_content_is $resp => '{"bar":"baz"}';

response_headers_include $resp, [ 'Content-Type' => 'application/json' ];

