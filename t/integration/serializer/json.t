use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;
use HTTP::Request::Common;
use JSON::MaybeXS ();
use Path::Tiny ();

# Serializer round trip and failure handling, through a real request.
#
# The two halves are asymmetric and both matter:
#
#   out - a route's return value is serialized, and the response must carry
#         the serializer's own content type rather than the text/html default.
#   in  - a request body is deserialized, but only for the methods that are
#         supposed to have one, and never for a multipart upload.
#
# A malformed body has to fail as a 400: the client sent something wrong, so
# there is no point telling it to try again.

my $UPLOAD;
BEGIN {
    $UPLOAD = Path::Tiny->tempdir;
    $UPLOAD->child('up.txt')->spew_raw('FILE-CONTENT');
}

{
    package JsonApp;
    use Dancer2;
    set logger     => 'null';
    set serializer => 'JSON';

    # Echoes what the deserializer produced, so the tests can tell "no body
    # was deserialized" from "the body deserialized to nothing".
    sub _report {
        return {
            method => request->method,
            data   => ( defined request->data ? request->data : 'NO-DATA' ),
            body   => body_parameters->as_hashref,
        };
    }

    get    '/echo' => sub { _report() };
    post   '/echo' => sub { _report() };
    put    '/echo' => sub { _report() };
    patch  '/echo' => sub { _report() };
    del    '/echo' => sub { _report() };

    get '/hash'   => sub { { a => 1 } };
    get '/array'  => sub { [ 1, 2, 3 ] };
    get '/string' => sub { 'plain string' };
    get '/utf8'   => sub { { m => "caf\x{e9}\x{263A}" } };
    get '/empty'  => sub { '' };
    get '/undef'  => sub { undef };

    post '/upload' => sub {
        return {
            files => [ sort keys %{ request->uploads } ],
            data  => ( defined request->data ? 'DESERIALIZED' : 'NO-DATA' ),
            name  => ( body_parameters->get('name') // 'undef' ),
        };
    };
}

my $test = Plack::Test->create( JsonApp->to_app );

sub json_body {
    my $response = shift;
    return JSON::MaybeXS::decode_json( $response->content );
}

# A request with an explicit method, headers and body - HTTP::Request::Common
# will not give a GET a body, and a GET with a body is one of the cases here.
sub raw_request {
    my ( $method, $path, $type, $body ) = @_;
    return HTTP::Request->new(
        $method, $path,
        [ defined $type ? ( 'Content-Type' => $type ) : () ],
        $body,
    );
}

subtest 'a serialized response carries the serializer content type' => sub {
    for my $case (
        [ '/hash',   { a => 1 } ],
        [ '/array',  [ 1, 2, 3 ] ],
    ) {
        my ( $path, $expected ) = @$case;
        my $response = $test->request( GET $path );

        is( $response->code, 200, "$path: responds" );
        is( $response->header('Content-Type'), 'application/json',
            "$path: content type is the serializer's, not text/html" );
        is_deeply( json_body($response), $expected,
            "$path: round-trips through JSON" );
    }

    # A route returning a plain, non-reference string still reaches
    # Response->content (Dancer2/Core/Route.pm:174-178: blessed($content) is
    # false for a plain string just as it is for an unblessed hash/arrayref,
    # so it goes to App::_prep_response, which does $response->content($content)
    # like any other value). content()'s 'around' modifier serializes
    # whenever a serializer is configured, with no ref-ness check
    # (Dancer2/Core/Response.pm:141-171). But the JSON serializer's encode()
    # requires a reference and dies on a plain scalar; that die is caught and
    # logged rather than propagated (Dancer2::Core::Role::Serializer's
    # 'around serialize'), so Response::serialize's own "or return" bails out
    # before ever setting the Content-Type to application/json
    # (Dancer2/Core/Response.pm:295-306). The net effect: a 200, the
    # *default* text/html content type (never overwritten), and an empty
    # body - the string is silently swallowed, not returned verbatim and not
    # JSON-encoded.
    my $string = $test->request( GET '/string' );
    is( $string->code, 200, '/string: responds' );
    is( $string->header('Content-Type'), 'text/html',
        '/string: a plain string does not get the serializer\'s content type' );
    is( $string->content, '',
        '/string: the serializer silently swallows a non-ref value, leaving no body' );

    # Characters must arrive as UTF-8 bytes, not as wide characters and not
    # as escaped ASCII.
    my $utf8 = $test->request( GET '/utf8' );
    is( $utf8->header('Content-Type'), 'application/json',
        '/utf8: content type is the serializer\'s' );
    is( $utf8->content, qq[{"m":"caf\xc3\xa9\xe2\x98\xba"}],
        '/utf8: the body is UTF-8 encoded bytes' );
    is_deeply( json_body($utf8), { m => "caf\x{e9}\x{263A}" },
        '/utf8: and decodes back to the original characters' );
};

subtest 'an empty serialized body loses the serializer content type' => sub {

    # Pinned as current behavior, not endorsed. Response::serialize bails out
    # before setting the content type when serialization produces something
    # falsey (Dancer2/Core/Response.pm:301), so a route returning '' or undef
    # under a JSON serializer answers text/html. A JSON client gets a content
    # type it did not ask for.
    for my $path ( '/empty', '/undef' ) {
        my $response = $test->request( GET $path );
        is( $response->code, 200, "$path: still a 200" );
        is( $response->content, '', "$path: with an empty body" );
        is( $response->header('Content-Type'), 'text/html',
            "$path: but the content type falls back to text/html" );
    }
};

subtest 'a malformed body is a 400, not a 500' => sub {
    my $response = $test->request(
        raw_request( POST => '/echo', 'application/json', '{"a":' ) );

    # 400, because the client sent bad input - re-sending will not help.
    is( $response->code, 400, 'a malformed JSON body is refused as 400' );

    # The error itself is serialized, so a JSON client can read the failure.
    is( $response->header('Content-Type'), 'application/json',
        'and the error is reported in the serializer\'s content type' );
    my $error = json_body($response);
    like( $error->{message}, qr/deserialize/i,
        'the message says deserialization is what failed' );

    # A valid body on the same route is the control.
    my $ok = $test->request(
        raw_request( POST => '/echo', 'application/json', '{"a":1}' ) );
    is( $ok->code, 200, 'a valid body on the same route is accepted' );
    is_deeply( json_body($ok)->{data}, { a => 1 },
        'and reaches the route deserialized' );
};

subtest 'an empty body is not a failure' => sub {
    my $response = $test->request(
        raw_request( POST => '/echo', 'application/json', '' ) );

    is( $response->code, 200, 'an empty body is not treated as malformed' );
    is( json_body($response)->{data}, 'NO-DATA',
        'there is simply nothing to deserialize' );
};

subtest 'only methods that may carry a body are deserialized' => sub {
    # These four are deserialized. DELETE is included deliberately: the RFC
    # leaves it undefined and Dancer2 takes the lenient route
    # (Dancer2/Core/Request.pm:202-206).
    for my $method (qw< POST PUT PATCH DELETE >) {
        my $response = $test->request(
            raw_request( $method => '/echo', 'application/json', '{"a":1}' ) );
        is( $response->code, 200, "$method: accepted" );
        is_deeply( json_body($response)->{data}, { a => 1 },
            "$method: body is deserialized" );
    }

    # A GET body is ignored entirely.
    my $get = $test->request(
        raw_request( GET => '/echo', 'application/json', '{"a":1}' ) );
    is( $get->code, 200, 'GET: accepted' );
    is( json_body($get)->{data}, 'NO-DATA',
        'GET: the body is not deserialized even when it is valid' );

    # The sharpest version: a GET carrying a *malformed* body must still be a
    # 200, which proves the deserializer was never reached rather than that it
    # ran and happened to succeed.
    my $bad_get = $test->request(
        raw_request( GET => '/echo', 'application/json', '{"a":' ) );
    is( $bad_get->code, 200,
        'GET: a malformed body does not even produce a 400' );
    is( json_body($bad_get)->{data}, 'NO-DATA',
        'GET: because nothing tried to deserialize it' );
};

subtest 'a multipart upload is not run through the deserializer' => sub {
    my $response = $test->request(
        POST '/upload',
        Content_Type => 'form-data',
        Content      => [
            name => 'ovid',
            file => [ $UPLOAD->child('up.txt')->stringify ],
        ],
    );

    is( $response->code, 200, 'the upload is accepted' );
    my $got = json_body($response);

    # The deserializer is skipped for multipart/form-data
    # (Dancer2/Core/Request.pm:191-196) - otherwise it would be handed the
    # MIME envelope and fail the request.
    is( $got->{data}, 'NO-DATA', 'the body was not deserialized' );

    # ...but the upload and the ordinary form field are still parsed.
    is_deeply( $got->{files}, ['file'], 'the uploaded file is still available' );
    is( $got->{name}, 'ovid', 'and so is a plain form field alongside it' );
};

done_testing();
