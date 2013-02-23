use strict;
use warnings;
use Test::More;

use Dancer2::Core::Request;

diag "If you want extract speed, install URL::Encode::XS"
  if !$Dancer2::Core::Request::XS_URL_DECODE;
diag "If you want extract speed, install CGI::Deurl::XS"
  if !$Dancer2::Core::Request::XS_PARSE_QUERY_STRING;

sub run_test {
    my $env = {
        'psgi.url_scheme'    => 'http',
        REQUEST_METHOD       => 'GET',
        SCRIPT_NAME          => '/foo',
        PATH_INFO            => '/bar/baz',
        REQUEST_URI          => '/foo/bar/baz',
        QUERY_STRING         => 'foo=42&bar=12&bar=13&bar=14',
        SERVER_NAME          => 'localhost',
        SERVER_PORT          => 5000,
        SERVER_PROTOCOL      => 'HTTP/1.1',
        REMOTE_ADDR          => '127.0.0.1',
        X_FORWARDED_FOR      => '127.0.0.2',
        X_FORWARDED_HOST     => 'secure.frontend',
        X_FORWARDED_PROTOCOL => 'https',
        REMOTE_HOST          => 'localhost',
        HTTP_USER_AGENT      => 'Mozilla',
        REMOTE_USER          => 'sukria',
    };

    my $req = Dancer2::Core::Request->new(env => $env);

    note "tests for accessors";

    is $req->agent,                 'Mozilla';
    is $req->user_agent,            'Mozilla';
    is $req->remote_address,        '127.0.0.1';
    is $req->address,               '127.0.0.1';
    is $req->forwarded_for_address, '127.0.0.2';
    is $req->remote_host,           'localhost';
    is $req->protocol,              'HTTP/1.1';
    is $req->port,                  5000;
    is $req->request_uri,           '/foo/bar/baz';
    is $req->uri,                   '/foo/bar/baz';
    is $req->user,                  'sukria';
    is $req->script_name,           '/foo';
    is $req->scheme,                'http';
    ok(!$req->secure);
    is $req->method,         'GET';
    is $req->request_method, 'GET';
    ok($req->is_get);
    ok(!$req->is_post);
    ok(!$req->is_put);
    ok(!$req->is_delete);
    ok(!$req->is_patch);
    ok(!$req->is_head);

    is $req->id,        1;
    is $req->to_string, '[#1] GET /foo/bar/baz';

    note "tests params";
    is_deeply { $req->params }, {foo => 42, bar => [12, 13, 14]};

    my $forward = $req->make_forward_to('/somewhere');
    is $forward->path_info, '/somewhere';
    is $forward->method,    'GET';
    note "tests for uri_for";
    is $req->base, 'http://localhost:5000/foo';
    is $req->uri_for('bar', {baz => 'baz'}),
      'http://localhost:5000/foo/bar?baz=baz';

    is $req->uri_for('/bar'), 'http://localhost:5000/foo/bar';
    ok $req->uri_for('/bar')->isa('URI'), 'uri_for returns a URI';
    ok $req->uri_for('/bar', undef, 1)->isa('URI'),
      'uri_for returns a URI (with $dont_escape)';

    is $req->request_uri, '/foo/bar/baz';
    is $req->path_info,   '/bar/baz';

    {
        local $env->{SCRIPT_NAME} = '';
        is $req->uri_for('/foo'), 'http://localhost:5000/foo';
    }

    {
        local $env->{SERVER_NAME} = 0;
        is $req->base, 'http://0:5000/foo';
        local $env->{HTTP_HOST} = 'oddhostname:5000';
        is $req->base, 'http://oddhostname:5000/foo';
    }

    {
        note "testing begind proxy";
        $req = Dancer2::Core::Request->new(
            env             => $env,
            is_behind_proxy => 1
        );
        is $req->secure, 1;
        is $req->host,   $env->{X_FORWARDED_HOST};
        is $req->scheme, 'https';
    }

    note "testing uri_base";
    $env = {
        'psgi.url_scheme' => 'http',
        REQUEST_METHOD    => 'GET',
        SCRIPT_NAME       => '/',
        PATH_INFO         => '/bar/baz',
        REQUEST_URI       => '/foo/bar/baz',
        QUERY_STRING      => '',
        SERVER_NAME       => 'localhost',
        SERVER_PORT       => 5000,
        SERVER_PROTOCOL   => 'HTTP/1.1',
    };

    $req = Dancer2::Core::Request->new(env => $env);
    is($req->uri_base, 'http://localhost:5000',
        'remove trailing slash if only one',
    );

    $env->{'SCRIPT_NAME'} = '/foo/';
    $req = Dancer2::Core::Request->new(env => $env);
    is($req->uri_base, 'http://localhost:5000/foo/',
        'keeping trailing slash if not only',
    );

    $env->{'PATH_INFO'}   = '/';
    $env->{'SCRIPT_NAME'} = '';
    $req = Dancer2::Core::Request->new(env => $env);
    is($req->uri_base, 'http://localhost:5000',);


    note "testing forward";
    $env = {
        'REQUEST_METHOD' => 'GET',
        'REQUEST_URI'    => '/',
        'PATH_INFO'      => '/',
        'QUERY_STRING'   => 'foo=bar&number=42',
    };

    $req = Dancer2::Core::Request->new(env => $env);
    is $req->path,   '/',   'path is /';
    is $req->method, 'GET', 'method is get';
    is_deeply scalar($req->params), {foo => 'bar', number => 42},
      'params are parsed';

    $req = $req->make_forward_to("/new/path");
    is $req->path,   '/new/path', 'path is changed';
    is $req->method, 'GET',       'method is unchanged';
    is_deeply scalar($req->params), {foo => 'bar', number => 42},
      'params are not touched';

    $req = $req->make_forward_to("/new/path", undef, {method => 'POST'});

    is $req->path,   '/new/path', 'path is changed';
    is $req->method, 'POST',      'method is changed';
    is_deeply scalar($req->params), {foo => 'bar', number => 42},
      'params are not touched';
}

diag "Run test with XS_URL_DECODE" if $Dancer2::Core::Request::XS_URL_DECODE;
diag "Run test with XS_PARSE_QUERY_STRING"
  if $Dancer2::Core::Request::XS_PARSE_QUERY_STRING;
run_test();
if ($Dancer2::Core::Request::XS_PARSE_QUERY_STRING) {
    diag "Run test without XS_PARSE_QUERY_STRING";
    $Dancer2::Core::Request::XS_PARSE_QUERY_STRING = 0;
    $Dancer2::Core::Request::_count                = 0;
    run_test();
}
if ($Dancer2::Core::Request::XS_URL_DECODE) {
    diag "Run test without XS_URL_DECODE";
    $Dancer2::Core::Request::XS_URL_DECODE = 0;
    $Dancer2::Core::Request::_count        = 0;
    run_test();
}

done_testing;
