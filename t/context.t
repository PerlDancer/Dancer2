use strict;
use warnings;

use Test::More;
use Dancer::Core::Context;

my $env = {
    'psgi.url_scheme' => 'http',
    REQUEST_METHOD    => 'GET',
    SCRIPT_NAME       => '/foo',
    PATH_INFO         => '/bar/baz',
    REQUEST_URI       => '/foo/bar/baz',
    QUERY_STRING      => 'foo=42&bar=12&bar=13&bar=14',
    SERVER_NAME       => 'localhost',
    SERVER_PORT       => 5000,
    SERVER_PROTOCOL   => 'HTTP/1.1',
    REMOTE_ADDR       => '127.0.0.1',
    X_FORWARDED_FOR => '127.0.0.2',
    REMOTE_HOST       => 'localhost',
    HTTP_USER_AGENT        => 'Mozilla',
    REMOTE_USER => 'sukria',
};

my $c = Dancer::Core::Context->new(env => $env);

isa_ok $c->request, 'Dancer::Core::Request';
is $c->request->method, 'GET';

done_testing;
