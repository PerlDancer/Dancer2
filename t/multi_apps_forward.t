#!perl

use strict;
use warnings;

use Test::More tests => 9;
use Plack::Test;
use HTTP::Request::Common;

{
    package App1;
    use Dancer2;

    get '/' => sub {'App1'};

    get '/forward' => sub {
        forward '/';
        ::ok( 0, 'Foward not returning right away!' );
    };

    get '/forward_to_new' => sub {
        forward '/new';
        ::ok( 0, 'Foward not returning right away!' );
    };
}

{
    package App2;
    use Dancer2;
    get '/'    => sub {'App2'};
    get '/new' => sub {'New'};
}

{
    # test each single app
    my $app1 = App1->psgi_app;
    test_psgi $app1, sub {
        my $cb = shift;
        is( $cb->( GET '/' )->code, 200, '[GET /] OK' );
        is( $cb->( GET '/' )->content, 'App1', '[GET /] OK content' );

        is( $cb->( GET '/forward' )->code, 200, '[GET /forward] OK' );
        is(
            $cb->( GET '/forward' )->content,
            'App1',
            '[GET /forward] OK content'
        );

        is(
            $cb->( GET '/forward_to_new' )->code,
            404,
            'Cannot find /new',
        );
    };

    my $app2 = App2->psgi_app;
    test_psgi $app2, sub {
        my $cb = shift;
        is( $cb->( GET '/' )->code, 200, '[GET /] OK' );
        is( $cb->( GET '/' )->content, 'App2', '[GET /] OK content' );
    };
}

{
    # test global
    my $app = Dancer2->psgi_app;
    test_psgi $app, sub {
        my $cb = shift;
        is(
            $cb->( GET '/forward_to_new' )->code,
            200,
            '[GET /forward_to_new] OK',
        );

        is(
            $cb->( GET '/forward_to_new' )->content,
            'New',
            '[GET /forward_to_new] OK content',
        );
    };
}
