use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common qw(GET);

{
    package TestApp;
    use Dancer2;

    prefix '/info';

    get '/foo' => sub {
        forward '/info/bar';
    };

    get '/bar' => sub {
        return request->uri_for('/delete');
    };

    get '/delete' => sub {
        return "DELETE OK";
    };
}

my $app = TestApp->to_app;

test_psgi
    app    => $app,
    client => sub {
        my $cb = shift;

        # Test forwarding + prefix handling
        my $res = $cb->( GET '/info/foo' );
        is( $res->code, 200, 'GET /info/foo returns 200' );

        like(
            $res->content,
            qr{/info/delete$},
            'uri_for returns prefixed delete path'
        );

        # Test the delete route
        my $res2 = $cb->( GET '/info/delete' );
        is( $res2->code, 200, 'GET /info/delete returns 200' );
        is( $res2->content, 'DELETE OK', 'delete route works' );
    };

done_testing;
