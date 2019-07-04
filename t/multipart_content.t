use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;
use Ref::Util qw<is_coderef>;

use Dancer2;

#
# Test for this issue: https://github.com/PerlDancer/Dancer2/issues/1507
# When a request comes with Content-Type: multipart/form-data with no boundary,
# Dancer currently wrongly returns HTTP code 500 Internal Server Error.
# It should return HTTP code 400 Bad Request.
# We also test that a request with Content-Type: multipart/form-data boundary=------boundary-------' returns 200.

my $app = __PACKAGE__->to_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    my $method = 'get';
    my $http = 'GET';

    eval "$method '/' => sub { '$method' }";

    { # $res->code is currently 500, so this test fails; this is correct until a fix is applied
        my $headers = [ 'Content-Type' => 'multipart/form-data' ];
        my $res = $cb->(HTTP::Request->new($http, '/', $headers));
        is($res->code, 400);
    }
    { # this test is passing
        my $headers = [ 'Content-Type' => 'Content-Type: multipart/form-data boundary=------boundary-------' ];
        my $res = $cb->(HTTP::Request->new($http, '/', $headers));
        is($res->code, 200);
    }
    {   # why is this test failing?? It's the same as previous one,
        # but with the 'Content-Type: ' bit not present in the header value.
        # $res->code is currently 500 for some reason.
        my $headers = [ 'Content-Type' => 'multipart/form-data boundary=------boundary-------' ];
        my $res = $cb->(HTTP::Request->new($http, '/', $headers));
        is($res->code, 200);
    }
    { # passes
        my $headers = [ 'Content-Type' => 'text/html; charset=UTF-8' ];
        my $res = $cb->(HTTP::Request->new($http, '/', $headers));
        is($res->code, 200);
    }
};

done_testing();