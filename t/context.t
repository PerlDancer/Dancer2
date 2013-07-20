use strict;
use warnings;

use Test::More;
use Dancer2::Core::Context;

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
    HTTP_COOKIE =>
      'dancer.session=1234; fbs_102="access_token=xxxxxxxxxx%7Cffffff"',
    X_FORWARDED_FOR => '127.0.0.2',
    REMOTE_HOST     => 'localhost',
    HTTP_USER_AGENT => 'Mozilla',
    REMOTE_USER     => 'sukria',
};

my $c = Dancer2::Core::Context->new( env => $env );

isa_ok $c->request, 'Dancer2::Core::Request';
is $c->request->method, 'GET';

isa_ok $c->cookies->{'dancer.session'}, 'Dancer2::Core::Cookie';
is $c->cookies->{'dancer.session'}->value,  1234;
is $c->cookies->{'dancer.session'}->name,   'dancer.session';
is $c->cookies->{'dancer.session'}->secure, 0;

done_testing;
