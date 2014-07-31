#!perl

use strict;
use warnings;

use Test::More tests => 10;
use Plack::Test;
use HTTP::Request::Common;

my $before;
{
    package OurApp;
    use Dancer2 '!pass';
    use Test::More;

    hook before => sub {
        my $ctx = shift;

        isa_ok(
            $ctx,
            'Dancer2::Core::App',
            'Context is actually an app now',
        );

        is( $ctx->name, 'OurApp', 'It is the correct app' );
        can_ok( $ctx, 'app' );

        my $app = $ctx->app;
        isa_ok(
            $app,
            'Dancer2::Core::App',
            'When called ->app, we get te app again',
        );

        is( $app->name, 'OurApp', 'It is the correct app' );
        is( $ctx, $app, 'Same exact application (by reference)' );

        $before++;
    };

    get '/' => sub {'OK'};
}

my $app = Dancer2->psgi_app;
isa_ok( $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb  = shift;
    my $res = $cb->( GET '/' );

    is( $res->code,     200, '[GET /] status OK'  );
    is( $res->content, 'OK', '[GET /] content OK' );

    ok( $before == 1, 'before hook called' );
};


