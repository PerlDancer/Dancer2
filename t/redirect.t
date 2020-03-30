use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

subtest 'basic redirects' => sub {
    {
        package App1;
        use Dancer2;

        get '/'         => sub {'home'};
        get '/bounce'   => sub { redirect '/' };
        get '/redirect' => sub { response_header 'X-Foo' => 'foo'; redirect '/'; };
        get '/redirect_querystring' => sub { redirect '/login?failed=1' };
        get '/redirect_uriescaped' => sub { redirect '?foo=bar+%26+baz' };
    }

    my $app = App1->to_app;
    ok( is_coderef($app), 'Got app' );

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
                '/',
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
                '/login?failed=1',
                'Correct Location header',
            );
        }

        {
            my $res = $cb->( GET '/redirect_uriescaped' );

            is( $res->code, 302, '[GET /redirect_uriescaped] Correct code' );

            is(
                $res->headers->header('Location'),
                '?foo=bar+%26+baz',
                'Correct Location header',
            );
        }
    };
};

# redirect absolute
subtest 'absolute and relative redirects' => sub {
    {
        package App2;
        use Dancer2;

        get '/absolute_with_host' =>
          sub { redirect "http://foo.com/somewhere"; };
        get '/absolute' => sub { redirect "/absolute"; };
        get '/relative' => sub { redirect "somewhere/else"; };
    }

    my $app = App2->to_app;
    ok( is_coderef($app), 'Got app' );

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
                '/absolute',
                'Correct Location header',
            );
        }

        {
            my $res = $cb->( GET '/relative' );

            is(
                $res->headers->header('Location'),
                'somewhere/else',
                'Correct Location header',
            );
        }
    };
};

done_testing;
