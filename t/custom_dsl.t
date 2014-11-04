use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Dancer2 dsl => 'MyDancerDSL';

envoie '/' => sub {
    request->method;
};

prend '/' => sub {
    request->method;
};

my $app = __PACKAGE__->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    is( $cb->( GET '/' )->content, 'GET', '[GET /] Correct content' );
    is( $cb->( POST '/' )->content, 'POST', '[POST /] Correct content' );
};

done_testing;
