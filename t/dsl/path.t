#!perl

use strict;
use warnings;

use Test::More tests => 4;
use Plack::Test;
use Plack::Request;
use Plack::Builder;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    get '/' => sub {
        my $dancer_req = request;
        my $env        = $dancer_req->env;
        my $plack_req  = Plack::Request->new($env);

        ::like(
            $env->{'PATH_INFO'},
            qr{^/?$},
            'PATH_INFO empty or /',
        );

        ::is(
            $dancer_req->path_info,
            $env->{'PATH_INFO'},
            'D2 path_info matches $env',
        );

        ::is(
            $dancer_req->path_info,
            $plack_req->path_info,
            'D2 path_info matches Plack path_info',
        );

        ::is( $dancer_req->path, '/', 'D2 path is /' );
        ::is( $plack_req->path, '/', 'Plack path is /' );

        return $dancer_req->script_name;
    };

    get '/endpoint' => sub {
        my $dancer_req = request;
        my $env        = $dancer_req->env;
        my $plack_req  = Plack::Request->new($env);

        ::is(
            $env->{'PATH_INFO'},
            '/endpoint',
            'PATH_INFO /endpoint',
        );

        ::is(
            $dancer_req->path_info,
            $env->{'PATH_INFO'},
            'D2 path_info matches $env',
        );

        ::is(
            $dancer_req->path_info,
            $plack_req->path_info,
            'D2 path_info matches Plack path_info',
        );

        ::is( $dancer_req->path, '/endpoint', 'D2 path is /' );
        ::is( $plack_req->path, '/endpoint', 'Plack path is /' );

        return $dancer_req->script_name;
    };
}

subtest '/' => sub {
    my $test = Plack::Test->create( App->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Result successful' );
    is( $res->content, '', 'script_name is empty' );
};

subtest '/endpoint' => sub {
    my $test = Plack::Test->create( App->to_app );
    my $res  = $test->request( GET '/endpoint' );
    ok( $res->is_success, 'Result successful' );
    is( $res->content, '', 'script_name is empty' );
};

subtest '/mounted/' => sub {
    my $app = builder {
        mount '/' => sub { [200,[],['OK']] };
        mount '/mounted' => App->to_app;
    };

    my $test = Plack::Test->create($app);

    my $res = $test->request( GET '/mounted/' );
    ok( $res->is_success, 'Result successful' );
    is( $res->content, '/mounted', 'script_name is /mounted' );
};

subtest '/mounted/endpoint' => sub {
    my $app = builder {
        mount '/' => sub { [200,[],['OK']] };
        mount '/mounted' => App->to_app;
    };

    my $test = Plack::Test->create($app);

    my $res = $test->request( GET '/mounted/endpoint' );
    ok( $res->is_success, 'Result successful' );
    is( $res->content, '/mounted', 'script_name is /mounted' );
};

