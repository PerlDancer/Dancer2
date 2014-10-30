use Test::More;
use strict;
use warnings;

use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;


    get '/foo/:name/*' => sub { "success" };
    get '/foo/*/:name' => sub { "success" };
}

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    my $res;

    $res = $cb->( GET "/foo/bar/baz" );

    is $res->code, 200;
};

done_testing();
