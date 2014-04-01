use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

{
    use Dancer2;
    get '/foo' => sub {
        return uri_for('/foo');
    };
}

my $app = Dancer2->runner->server->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    is( $cb->( GET '/foo' )->code, 200, '/foo code okay' );
    is(
        $cb->( GET '/foo' )->content,
        'http://localhost/foo',
        'uri_for works as expected',
    );
};

done_testing;
