use strict;
use warnings;

use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

{
    package MyApp;
    use Dancer2;
    set serializer => 'JSON';
    get '/json'    => sub { +{ bar => 'baz' } };
}

my $app = MyApp->to_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    {
        # Response with implicit call to the serializer
        my $res = $cb->( GET '/json' );
        is( $res->code, 200, '[/json] Correct status' );
        is( $res->content, '{"bar":"baz"}', '[/json] Correct content' );
        is(
            $res->headers->content_type,
            'application/json',
            '[/json] Correct content-type headers',
        );
    }
};
