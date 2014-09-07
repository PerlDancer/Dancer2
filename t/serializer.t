use strict;
use warnings;

use Test::More tests => 9;
use Dancer2::Serializer::Dumper;
use Plack::Test;
use HTTP::Request::Common;

{

    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    get '/json'    => sub { return { bar => 'baz' } };
    get '/to_json' => sub { to_json({bar => 'baz'}, {pretty => 1}) };
}

my $app = MyApp->to_app;
is( ref $app, 'CODE', 'Got app' );

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

    {
        # Response with explicit call to the serializer
        my $res = $cb->( GET '/to_json' );
        is( $res->code, 200, '[/to_json] Correct status' );
        is(
            $res->content,
            "{\n   \"bar\" : \"baz\"\n}\n",
            '[/to_json] Correct content',
        );

        # When calling `to_json', the content_type is not set,
        # because we can't assume we're calling it for a response
        is(
            $res->headers->content_type,
            'text/html',
            '[/to_json] Correct content-type headers',
        );

        is(
            $res->headers->content_type_charset,
            'UTF-8',
            '[/to_json] Correct content-type charset headers',
        );
    }
};

my $serializer = Dancer2::Serializer::Dumper->new();

is(
    $serializer->content_type,
    'text/x-data-dumper',
    'content-type is set correctly',
);
