use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

subtest 'basic redirects' => sub {
    {
        package App;
        use Dancer2;

        get '/'         => sub {'home'};
        get '/bounce'   => sub { redirect '/' };
        get '/redirect' => sub { header 'X-Foo' => 'foo'; redirect '/'; };
        get '/redirect_querystring' => sub { redirect '/login?failed=1' };
    }

    my $app = Dancer2->runner->server->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        {
            my $res = $cb->( GET '/' );

            is( $res->code, 200, '[GET /] Correct code' );
            is( $res->content, 'home', '[GET /] Correct content' );

            is(
                $res->headers->content_type,
                'text/html',
                '[GET /] Correct content-type',
            );

            is(
                $cb->( GET '/bounce' )->code,
                302,
                '[GET /bounce] Correct code',
            );
        }

        {
            my $res = $cb->( GET '/redirect' );

            is( $res->code, 302, '[GET /redirect] Correct code' );

            is(
                $res->headers->header('Location'),
                'http://localhost/',
                'Correct Location header',
            );

            is(
                $res->headers->header('X-Foo'),
                'foo',
                'Correct X-Foo header',
            );
        }

        {
            my $res = $cb->( GET '/redirect_querystring' );

            is( $res->code, 302, '[GET /redirect_querystring] Correct code' );

            is(
                $res->headers->header('Location'),
                'http://localhost/login?failed=1',
                'Correct Location header',
            );
        }
    };
};

# redirect absolute
subtest 'absolute and relative redirects' => sub {
    {

        package App;
        use Dancer2;

        get '/absolute_with_host' =>
          sub { redirect "http://foo.com/somewhere"; };
        get '/absolute' => sub { redirect "/absolute"; };
        get '/relative' => sub { redirect "somewhere/else"; };
    }

    my $app = Dancer2->runner->server->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        {
            my $res = $cb->( GET '/absolute_with_host' );

            is(
                $res->headers->header('Location'),
                'http://foo.com/somewhere',
                'Correct Location header',
            );
        }

        {
            my $res = $cb->( GET '/absolute' );

            is(
                $res->headers->header('Location'),
                'http://localhost/absolute',
                'Correct Location header',
            );
        }

        {
            my $res = $cb->( GET '/relative' );

            is(
                $res->headers->header('Location'),
                'http://localhost/somewhere/else',
                'Correct Location header',
            );
        }
    };
};

subtest 'redirect behind a proxy' => sub {
    {
        package App;
        use Dancer2;
        prefix '/test2';
        set behind_proxy => 1;
        get '/bounce' => sub { redirect '/test2' };
    }

    my $app = Dancer2->runner->server->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST' => 'nice.host.name',
                )->headers->header('Location'),
                'http://nice.host.name/test2',
                'behind a proxy, host() is read from X_FORWARDED_HOST',
            );
        }

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST' => 'nice.host.name',
                    'FORWARDED-PROTO'  => 'https',
                )->headers->header('Location'),
                'https://nice.host.name/test2',
                '... and the scheme is read from HTTP_FORWARDED_PROTO',
            );
        }

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST'     => 'nice.host.name',
                    'X-FORWARDED-PROTOCOL' => 'ftp', # stupid, but why not?
                )->headers->header('Location'),
                'ftp://nice.host.name/test2',
                '... or from X_FORWARDED_PROTOCOL',
            );
        }
    };
};

subtest 'redirect behind multiple proxies' => sub {
    {

        package App;
        use Dancer2;
        prefix '/test2';
        set behind_proxy => 1;
        get '/bounce' => sub { redirect '/test2' };
    }

    my $app = Dancer2->runner->server->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST' => "proxy1.example, proxy2.example",
                )->headers->header('Location'),
                'http://proxy1.example/test2',
                "behind multiple proxies, host() is read from X_FORWARDED_HOST",
            );
        }

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST' => "proxy1.example, proxy2.example",
                    'FORWARDED-PROTO'  => 'https',
                )->headers->header('Location'),
                'https://proxy1.example/test2',
                '... and the scheme is read from HTTP_FORWARDED_PROTO',
            );
        }

        {
            is(
                $cb->(
                    GET '/test2/bounce',
                    'X-FORWARDED-HOST'     => "proxy1.example, proxy2.example",
                    'X-FORWARDED-PROTOCOL' => 'ftp', # stupid, but why not?
                )->headers->header('Location'),
                'ftp://proxy1.example/test2',
                '... or from X_FORWARDED_PROTOCOL',
            );
        }
    };
};

done_testing;
