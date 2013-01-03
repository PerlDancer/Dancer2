use strict;
use warnings;

use Test::More;

subtest 'basic redirects' => sub {
    {
        package App;
        use Dancer;

        get '/'         => sub { 'home' };
        get '/bounce'   => sub { redirect '/' };
        get '/redirect' => sub { header 'X-Foo' => 'foo'; redirect '/'; };
        get '/redirect_querystring' => sub { redirect '/login?failed=1' };
    }
    use Dancer::Test apps => ['App'];

    response_status_is  [ GET => '/' ] => 200;
    response_content_is [ GET => '/' ] => "home";

    response_status_is  [ GET => '/bounce' ] => 302;

    my $expected_headers = [
        'Location'     => 'http://localhost/',
        'Content-Type' => 'text/html',
        'X-Foo'        => 'foo',
    ];
    response_headers_include [ GET => '/redirect' ] => $expected_headers;

    $expected_headers = [
        'Location'     => 'http://localhost/login?failed=1',
        'Content-Type' => 'text/html',
    ];
    response_headers_include [ GET => '/redirect_querystring' ] =>
      $expected_headers;
};

# redirect absolute
subtest 'absolute and relative redirects' => sub {
    { 
        package App;
        use Dancer;

        get '/absolute_with_host' =>
          sub { redirect "http://foo.com/somewhere"; };
        get '/absolute' => sub { redirect "/absolute"; };
        get '/relative' => sub { redirect "somewhere/else"; };
    }
    use Dancer::Test apps => ['App'];

    response_headers_include
      [ GET => '/absolute_with_host' ],
      [ Location => 'http://foo.com/somewhere' ];

    response_headers_include
      [ GET => '/absolute' ],
      [ Location => 'http://localhost/absolute' ];

    response_headers_include
      [ GET => '/relative' ],
      [ Location => 'http://localhost/somewhere/else' ];
};

subtest 'redirect behind a proxy' => sub {
    { 
        package App;
        use Dancer;
        set behind_proxy => 1;
        get '/bounce'   => sub { redirect '/' };
    }
    use Dancer::Test apps => ['App'];

    $ENV{X_FORWARDED_HOST} = "nice.host.name";
    response_headers_include
      [GET      => '/bounce'],
      [Location => 'http://nice.host.name/'],
      "behind a proxy, host() is read from X_FORWARDED_HOST";

    $ENV{HTTP_FORWARDED_PROTO} = "https";
    response_headers_include [GET => '/bounce'] =>
      [Location => 'https://nice.host.name/'],
      "... and the scheme is read from HTTP_FORWARDED_PROTO";

    $ENV{X_FORWARDED_PROTOCOL} = "ftp";    # stupid, but why not?
    response_headers_include [GET => '/bounce'] =>
      [Location => 'ftp://nice.host.name/'],
      "... or from X_FORWARDED_PROTOCOL";
};

done_testing;
