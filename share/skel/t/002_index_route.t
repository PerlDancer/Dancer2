use strict;
use warnings;

use [% appname %];
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    ok( $cb->( GET '/' )->is_success, '[GET /] successful' );
};

