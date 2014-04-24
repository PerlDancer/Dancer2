use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use Dancer2;

any [ 'get', 'post' ], '/' => sub {
    request->method;
};

my $app = Dancer2->runner->server->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    is( $cb->( GET '/'  )->content, 'GET',  'GET / correct content'  );
    is( $cb->( POST '/' )->content, 'POST', 'POST / correct content' );
};

done_testing;
