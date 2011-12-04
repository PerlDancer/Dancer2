use strict;
use warnings;
use Test::More import => [ '!pass' ];

use Dancer::Core::App;
use Dancer::Core::Context;
use Dancer::Core::Response;
use Dancer::Core::Request;
use Dancer::Core::Error;

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
    HTTP_COOKIE       => 'dancer.session=1234; fbs_102="access_token=xxxxxxxxxx%7Cffffff"',
    X_FORWARDED_FOR => '127.0.0.2',
    REMOTE_HOST       => 'localhost',
    HTTP_USER_AGENT        => 'Mozilla',
    REMOTE_USER => 'sukria',
};

my $a = Dancer::Core::App->new(name => 'main');
my $c = Dancer::Core::Context->new(env => $env);

subtest 'basic defaults' => sub {
    my $e = Dancer::Core::Error->new(
        app => $a,
        context => $c,
    );
    is $e->code, 500;
    is $e->title, 'Error 500';
    is $e->message, '';
};

done_testing;
