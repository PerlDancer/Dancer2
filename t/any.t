use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

{

    package App;
    use Dancer2;

    any [ 'get', 'post' ] => '/test' => sub {
        request->method;
    };

    any '/all' => sub {
        request->method;
    };
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    is( $cb->( POST '/test' )->content, 'POST', 'POST request successful' );
    is( $cb->( GET '/test' )->content, 'GET', 'GET request successful' );

    for my $method ( qw<GET POST PUT DELETE OPTIONS PATCH> ) {
        my $req = HTTP::Request->new( $method => '/all' );
        is(
            $cb->($req)->content,
            $method,
            "$method request successful",
        );
    }
};

done_testing;

