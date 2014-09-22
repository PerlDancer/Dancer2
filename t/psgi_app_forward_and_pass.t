#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;

{
    package App1;
    use Dancer2;
    get '/' => sub {'App1'};
}

{
    package App2;
    use Dancer2;
    get '/pass' => sub { pass };
}

{
    package App3;
    use Dancer2;
    get '/pass' => sub {'App3'};
    get '/forward' => sub { forward '/' };
}

# pass from App2 to App3
# forward from App3 to App1
my $app = Dancer2->psgi_app;
isa_ok( $app, 'CODE' );

test_psgi $app, sub {
    my $cb = shift;

    is( $cb->( GET '/' )->content, 'App1', 'Simple request' );

    is(
        $cb->( GET '/pass' )->content,
        'App3',
        'Passing from App to App works',
    );

    is(
        $cb->( GET '/forward' )->content,
        'App1',
        'Forwarding from App to App works',
    );
};
