use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use Dancer2;

set behind_proxy => 1;

get '/' => sub {
    'home:' . join( ',', params );
};
get '/bounce/' => sub {
    return forward '/';
};
get '/bounce/:withparams/' => sub {
    return forward '/';
};
get '/bounce2/adding_params/' => sub {
    return forward '/', { withparams => 'foo' };
};
post '/simple_post_route/' => sub {
    'post:' . join( ',', params );
};
get '/go_to_post/' => sub {
    return forward '/simple_post_route/', { foo => 'bar' },
      { method => 'post' };
};
get '/proxy/' => sub {
    return uri_for('/');
};
get '/forward_with_proxy/' => sub {
    forward '/proxy/';
};

# NOT SUPPORTED IN DANCER2
# In dancer2, vars are alive for only one request flow, a forward initiate a
# new request flow, then the vars HashRef is destroyed.
#
# get '/b' => sub { vars->{test} = 1;  forward '/a'; };
# get '/a' => sub { return "test is " . var('test'); };

my $app = __PACKAGE__->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    is( $cb->( GET '/' )->code, 200, '[GET /] Correct code' );
    is( $cb->( GET '/' )->content, 'home:', '[GET /] Correct content' );

    is( $cb->( GET '/bounce/' )->code, 200, '[GET /bounce] Correct code' );
    is(
        $cb->( GET '/bounce/' )->content,
        'home:',
        '[GET /bounce] Correct content',
    );

    is(
        $cb->( GET '/bounce/thesethings/' )->code,
        200,
        '[GET /bounce/thesethings/] Correct code',
    );

    is(
        $cb->( GET '/bounce/thesethings/' )->content,
        'home:withparams,thesethings',
        '[GET /bounce/thesethings/] Correct content',
    );

    is(
        $cb->( GET '/bounce2/adding_params/' )->code,
        200,
        '[GET /bounce2/adding_params/] Correct code',
    );

    is(
        $cb->( GET '/bounce2/adding_params/' )->content,
        'home:withparams,foo',
        '[GET /bounce2/adding_params/] Correct content',
    );

    is(
        $cb->( GET '/go_to_post/' )->code,
        200,
        '[GET /go_to_post/] Correct code',
    );

    is(
        $cb->( GET '/go_to_post/' )->content,
        'post:foo,bar',
        '[GET /go_to_post/] Correct content',
    );

    # NOT SUPPORTED
    # response_status_is  [ GET => '/b' ] => 200;
    # response_content_is [ GET => '/b' ] => 'test is 1';

    {
        my $res = $cb->( GET '/bounce/' );

        is(
            $res->headers->content_length,
            5,
            '[GET /bounce/] Correct content length',
        );

        is(
            $res->headers->content_type,
            'text/html',
            '[GET /bounce/] Correct content type',
        );

        is(
            $res->headers->content_type_charset,
            'UTF-8',
            '[GET /bounce/] Correct content type charset',
        );

        is(
            $res->headers->server,
            "Perl Dancer2 " . Dancer2->VERSION,
            '[GET /bounce/] Correct Server',
        );

    }

    # checking post
    post '/'        => sub {'post-home'};
    post '/bounce/' => sub { forward('/') };

    is( $cb->( POST '/' )->code, 200, '[POST /] Correct code' );
    is( $cb->( POST '/' )->content, 'post-home', '[POST /] Correct content' );

    is(
        $cb->( POST '/bounce/' )->code,
        200,
        '[POST /bounce/] Correct code',
    );

    is(
        $cb->( POST '/bounce/' )->content,
        'post-home',
        '[POST /bounce/] Correct content',
    );

    {
        my $res = $cb->( POST '/bounce/' );

        is(
            $res->headers->content_length,
            9,
            '[POST /bounce/] Correct content length',
        );

        is(
            $res->headers->content_type,
            'text/html',
            '[POST /bounce/] Correct content type',
        );

        is(
            $res->headers->content_type_charset,
            'UTF-8',
            '[POST /bounce/] Correct content type charset',
        );

        is(
            $res->headers->server,
            "Perl Dancer2 " . Dancer2->VERSION,
            '[POST /bounce/] Correct Server',
        );
    }

    is(
        $cb->( GET '/forward_with_proxy/', 'X-Forwarded-Proto' => 'https' )->content,
        'https://localhost/',
        '[GET /forward_with_proxy/] maintained is_behind_proxy',
    );
};

done_testing;
