use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request;

# Dancer2::Serializer::Mutable picks a format per request from the HTTP
# headers. It makes that choice twice, by two different rules:
#
#   deserialize - _get_content_type('content_type'), so the request's
#                 Content-Type decides how the incoming body is read.
#   serialize   - _get_content_type('accept'), so the request's Accept
#                 decides how the outgoing body is written.
#
# That asymmetry is intentional and documented: Accept is the header a
# client uses to say what it wants back, so it is consulted first when
# choosing a response format, while Content-Type - what the client says it
# sent - is consulted first when reading the request body.
#
# The lookup matches on the content type alone: any ';'-separated parameters
# (such as '; charset=utf-8') are stripped, and the result is lowercased,
# before comparing against the mapping. That used to not be true - a
# charset parameter was an exact-match miss that silently fell back to JSON,
# turning a valid YAML request into a 400. It is asserted below as fixed.

{
    package MutableApp;
    use Dancer2;
    set logger     => 'null';
    set serializer => 'Mutable';

    get  '/out'   => sub { { a => 1 } };
    post '/round' => sub { { got => request->data } };
}

my $test = Plack::Test->create( MutableApp->to_app );

sub hit {
    my ( $method, $path, $headers, $body ) = @_;
    return $test->request(
        HTTP::Request->new( $method, $path, $headers || [], $body ) );
}

subtest 'Accept chooses the outgoing format' => sub {
    my %expected = (
        'application/json'   => [ 'application/json',   qr/^\{"a":1\}$/ ],
        'text/x-json'        => [ 'text/x-json',         qr/^\{"a":1\}$/ ],
        'text/x-yaml'        => [ 'text/x-yaml',         qr/^---\na: 1\n$/ ],
        'text/html'          => [ 'text/html',           qr/^---\na: 1\n$/ ],
    );

    for my $accept ( sort keys %expected ) {
        my ( $content_type, $body_like ) = @{ $expected{$accept} };
        my $response = hit( GET => '/out', [ Accept => $accept ] );

        is( $response->code, 200, "Accept: $accept responds" );
        is( $response->header('Content-Type'), $content_type,
            "Accept: $accept sets Content-Type to match" );
        like( $response->content, $body_like,
            "Accept: $accept serializes in that format" );
    }
};

subtest 'an unrecognised or absent Accept falls back to JSON' => sub {
    # 'text/x-data-dumper' is in this list rather than the one above because
    # the Dumper serializer is no longer part of the default mapping: it
    # deserializes by evaluating the request body as perl, so it must now be
    # opted into with engines.serializer.Mutable.enable_dumper. This app does
    # not set it, so the type is simply unrecognised and falls through to the
    # default - which is the point worth asserting, since falling back to
    # JSON rather than quietly reaching for Dumper is what keeps an
    # unconfigured app away from the eval.
    for my $accept (
        'application/xml', 'text/plain', '*/*', 'text/x-data-dumper' )
    {
        my $response = hit( GET => '/out', [ Accept => $accept ] );
        is( $response->header('Content-Type'), 'application/json',
            "Accept: $accept falls back to JSON" );
        is( $response->content, '{"a":1}', "Accept: $accept body is JSON" );
    }

    my $bare = hit( GET => '/out' );
    is( $bare->header('Content-Type'), 'application/json',
        'no Accept header at all falls back to JSON' );
    is( $bare->content, '{"a":1}', 'with a JSON body' );
};

subtest 'Content-Type chooses the incoming format' => sub {
    # YAML in, and (with no Accept header) JSON is *not* what comes back -
    # _get_content_type('accept') falls through to content_type, so the
    # response follows the request's Content-Type here.
    my $yaml = hit( POST => '/round', [ 'Content-Type' => 'text/x-yaml' ],
        "---\na: 1\n" );
    is( $yaml->code, 200, 'a YAML body is accepted' );
    like( $yaml->content, qr/^---\n/, 'and answered in YAML' );
    like( $yaml->content, qr/a: 1/, 'with the deserialized value' );

    my $json = hit( POST => '/round', [ 'Content-Type' => 'application/json' ],
        '{"a":1}' );
    is( $json->code, 200, 'a JSON body is accepted' );
    is( $json->content, '{"got":{"a":1}}',
        'deserialized and answered in JSON' );

    # An unrecognised Content-Type falls back to JSON for the *input* too,
    # which is why a JSON body under a bogus type still works.
    my $unknown = hit( POST => '/round',
        [ 'Content-Type' => 'application/xml' ], '{"a":1}' );
    is( $unknown->code, 200,
        'an unrecognised Content-Type falls back to JSON' );
    is( $unknown->content, '{"got":{"a":1}}',
        'so a JSON body under a bogus content type is still read' );
};

subtest 'Accept wins over Content-Type when serializing (documented)' => sub {

    # The module's DESCRIPTION documents two different priority orders:
    # Content-Type first when deserializing a request body, but Accept first
    # when serializing a response - because Accept is the header a client
    # uses to say what format it wants *back*, which need not match what it
    # sent. serialize() calls _get_content_type('accept'), which checks the
    # headers in the order accept, content_type, accept
    # (Dancer2/Serializer/Mutable.pm:68 and :95), so Accept wins on the way
    # out while Content-Type still wins on the way in. The round trip is
    # therefore asymmetric by design: YAML in, JSON out below.

    my $response = hit(
        POST => '/round',
        [ 'Content-Type' => 'text/x-yaml', 'Accept' => 'application/json' ],
        "---\na: 1\n",
    );

    is( $response->code, 200, 'the request succeeds' );

    # The body was read as YAML, per the documented rule for deserializing.
    like( $response->content, qr/"got"/,
        'the response is JSON, chosen from Accept' );
    is( $response->header('Content-Type'), 'application/json',
        'and says so, per the documented rule for serializing' );

    # The mirror image, to show it is the Accept header doing this and not
    # something about YAML: JSON in, YAML out.
    my $mirror = hit(
        POST => '/round',
        [ 'Content-Type' => 'application/json', 'Accept' => 'text/x-yaml' ],
        '{"a":1}',
    );
    is( $mirror->header('Content-Type'), 'text/x-yaml',
        'a JSON request is answered in YAML when Accept asks for it' );
    like( $mirror->content, qr/^---\n/, 'with a YAML body' );
};

subtest 'a charset parameter on Content-Type is stripped before the lookup (fixed)' => sub {

    # The lookup now strips any ';'-separated parameters and lowercases
    # what remains before matching against the mapping
    # (Dancer2/Serializer/Mutable.pm:96-105), so a charset parameter no
    # longer causes a miss. Previously 'text/x-yaml; charset=utf-8' missed
    # the 'text/x-yaml' key, fell through to the JSON default, and then JSON
    # was handed a YAML body and failed the request as a 400.
    #
    # A charset parameter on Content-Type is entirely ordinary, so this is
    # reachable from any normal client.

    # The control: the identical request without the parameter works.
    # No Accept header is sent, so serialize() falls through to
    # Content-Type for the outgoing format too (see the previous subtest) -
    # these all round-trip as YAML, not JSON.
    my $plain = hit( POST => '/round', [ 'Content-Type' => 'text/x-yaml' ],
        "---\na: 1\n" );
    is( $plain->code, 200, 'text/x-yaml alone is understood' );
    like( $plain->content, qr/got:\s*\n\s*a: 1/,
        'and the YAML body is deserialized' );

    my $with_charset = hit( POST => '/round',
        [ 'Content-Type' => 'text/x-yaml; charset=utf-8' ], "---\na: 1\n" );
    is( $with_charset->code, 200,
        'the same body with "; charset=utf-8" is now understood too' );
    is( $with_charset->content, $plain->content,
        'and deserializes exactly as the bare header does' );

    # Case is folded too: the mapping keys are matched case-insensitively.
    my $uppercase = hit( POST => '/round',
        [ 'Content-Type' => 'TEXT/X-YAML' ], "---\na: 1\n" );
    is( $uppercase->code, 200, 'an uppercase spelling is understood as well' );
    is( $uppercase->content, $plain->content,
        'and deserializes the same way' );

    # JSON continues to work, now for the right reason rather than by
    # accident of the fallback also being JSON.
    my $json_charset = hit( POST => '/round',
        [ 'Content-Type' => 'application/json; charset=utf-8' ], '{"a":1}' );
    is( $json_charset->code, 200,
        'JSON with a charset parameter still works' );
    is( $json_charset->content, '{"got":{"a":1}}',
        'because the parameter is stripped, not because of the fallback' );

    # Same fix on the way out: the Accept lookup strips parameters too, so
    # this no longer silently falls back to JSON.
    my $accept_charset = hit( GET => '/out',
        [ Accept => 'text/x-yaml; charset=utf-8' ] );
    is( $accept_charset->header('Content-Type'), 'text/x-yaml',
        'an Accept with a charset parameter now chooses YAML, not JSON' );
    like( $accept_charset->content, qr/^---\na: 1\n$/,
        'with a YAML body' );
};

done_testing();
