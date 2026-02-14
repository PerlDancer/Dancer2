#!perl

use strict;
use warnings;

use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;
use Path::Tiny qw< path >;

{
    package App;
    use Dancer2;

    get '/' => sub { app->caller };

}

my $app = App->to_app;
test_psgi $app, sub {
    my $cb  = shift;
    my $res = $cb->( GET '/' );

    is( $res->code, 200, '[GET /] Successful' );
    is(
        path( $res->content )->stringify,
        path(qw<t caller.t>)->stringify,
        'Correct App name from caller',
    );
};
