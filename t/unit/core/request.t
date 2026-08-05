use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;
use Encode ();

use Dancer2::Core::Request;

# Unit tests: request objects are built straight from a PSGI environment, with
# no app and no dispatcher, so a failure here names the request layer rather
# than something further up.
#
# Two accessor families coexist and do not agree, deliberately:
#
#   params()            - the legacy flat hash. Repeated values become an
#                         arrayref, and it is where splat/captures live.
#   *_parameters()      - Hash::MultiValue, per source, plus a merged view.
#                         splat and captures are kept out of these.
#
# Both are asserted, because "fixing" either to look like the other would be a
# silent behavior change for existing applications.

# A minimal but complete PSGI env. CONTENT_LENGTH matters: without it
# Plack::Request will not read the body at all.
sub psgi_env {
    my %opt = @_;
    my $body = defined $opt{body} ? $opt{body} : '';
    open my $input, '<', \$body or die "cannot open in-memory body: $!";

    return {
        REQUEST_METHOD    => $opt{method} || 'GET',
        PATH_INFO         => defined $opt{path} ? $opt{path} : '/',
        QUERY_STRING      => defined $opt{query} ? $opt{query} : '',
        SCRIPT_NAME       => '',
        SERVER_NAME       => 'localhost',
        SERVER_PORT       => 80,
        CONTENT_LENGTH    => length $body,
        'psgi.url_scheme' => 'http',
        'psgi.input'      => $input,
        'psgi.errors'     => \*STDERR,
        ( $opt{ctype} ? ( CONTENT_TYPE => $opt{ctype} ) : () ),
        %{ $opt{extra} || {} },
    };
}

sub form_request {
    my %opt = @_;
    return Dancer2::Core::Request->new(
        env => psgi_env( %opt, ctype => 'application/x-www-form-urlencoded' ),
        ( $opt{strict_utf8} ? ( strict_utf8 => 1 ) : () ),
    );
}

subtest 'route parameters outrank body, body outranks query' => sub {
    my $req = form_request(
        method => 'POST',
        query  => 'who=query&only_query=q',
        body   => 'who=body&only_body=b',
    );

    # Before a route matches there are no route parameters, so body wins.
    is( $req->params->{who}, 'body',
        'a body parameter beats a query parameter of the same name' );

    # This is what App::_dispatch does once a route matches.
    $req->_set_route_params(     { who => 'route' } );
    $req->_set_route_parameters( { who => 'route' } );

    is( $req->params->{who}, 'route',
        'a route parameter beats both' );

    # The losers are still reachable through their own source.
    is( $req->params('query')->{who}, 'query', 'the query value is still there' );
    is( $req->params('body')->{who},  'body',  'the body value is still there' );
    is( $req->params('route')->{who}, 'route', 'and so is the route value' );

    # Names that appear in only one place are unaffected by any of this.
    is( $req->params->{only_query}, 'q', 'a query-only name comes through' );
    is( $req->params->{only_body},  'b', 'a body-only name comes through' );

    like( exception { $req->params('nonsense') },
        qr/Unknown source params/,
        'an unknown source is refused rather than silently returning nothing' );

    # The merged Hash::MultiValue keeps all three, in query-body-route order.
    is_deeply(
        [ $req->parameters->get_all('who') ],
        [ 'query', 'body', 'route' ],
        'the merged view keeps every value, query first and route last',
    );
    is( scalar $req->parameters->get('who'), 'route',
        'and its single-value read gives the last one, so route still wins' );
};

subtest 'a repeated query parameter keeps every value' => sub {
    my $req = Dancer2::Core::Request->new(
        env => psgi_env( query => 'a=1&a=2&a=3&b=solo' ) );

    is_deeply( $req->params->{a}, [ '1', '2', '3' ],
        'params() collapses a repeated name to an arrayref of all values' );
    is( $req->params->{b}, 'solo',
        'a single value stays a plain scalar, not a one-element array' );

    is_deeply( [ $req->query_parameters->get_all('a') ], [ '1', '2', '3' ],
        'get_all on the query parameters returns all three' );
    is( scalar $req->query_parameters->get('a'), '3',
        'and the single-value read gives the last, per Hash::MultiValue' );
};

subtest 'UTF-8 in the query string and the path is decoded to characters' => sub {
    # 'été' and '/café' as the bytes a client would actually send.
    my $req = Dancer2::Core::Request->new( env => psgi_env(
        query => 'name=%C3%A9t%C3%A9',
        path  => "/caf\xc3\xa9",
    ) );

    my $name = $req->params->{name};
    ok( utf8::is_utf8($name), 'the query value is decoded, not raw bytes' );
    is( length $name, 3, 'and is three characters, not five bytes' );
    is( Encode::encode_utf8($name), "\xc3\xa9t\xc3\xa9",
        'round-tripping it reproduces the original bytes' );

    my $path = $req->path;
    ok( utf8::is_utf8($path), 'the path is decoded too' );
    is( length $path, 5, 'and is five characters, not six bytes' );

    my $via_hmv = scalar $req->query_parameters->get('name');
    ok( utf8::is_utf8($via_hmv),
        'the Hash::MultiValue accessor decodes as well, not only params()' );
    is( $via_hmv, $name, 'and agrees with params()' );
};

subtest 'invalid UTF-8 is passed through with a warning by default' => sub {
    my $req = Dancer2::Core::Request->new( env => psgi_env( query => 'x=%FF%FE' ) );

    my @warnings;
    my $value = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $req->params->{x};
    };

    # Lenient mode: the request survives and the caller gets the bytes.
    ok( !utf8::is_utf8($value), 'the value is left as bytes, undecoded' );
    is( $value, "\xFF\xFE", 'and the bytes are unchanged' );

    is( scalar @warnings, 1, 'exactly one warning is emitted' );
    like( $warnings[0], qr/Invalid UTF-8 in query parameters/,
        'naming what was invalid and where' );
    like( $warnings[0], qr/leaving bytes unchanged/,
        'and saying what it did about it' );
};

subtest 'invalid UTF-8 goes to the PSGI logger when there is one' => sub {
    my @logged;
    my $req = Dancer2::Core::Request->new( env => psgi_env(
        query => 'x=%FF%FE',
        extra => { 'psgix.logger' => sub { push @logged, $_[0] } },
    ) );

    my @warnings;
    my $value = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $req->params->{x};
    };

    is( scalar @logged, 1, 'the message goes to the PSGI logger' );
    is( $logged[0]{level}, 'warning', 'at warning level' );
    like( $logged[0]{message}, qr/Invalid UTF-8 in query parameters/,
        'with the same message' );

    # This is the point of the branch: a server that provides a logger does
    # not also get warnings on STDERR.
    is( scalar @warnings, 0, 'and not also to STDERR' );
    is( $value, "\xFF\xFE", 'the bytes still come through unchanged' );
};

subtest 'invalid UTF-8 is fatal when strict_utf8 is on' => sub {
    my $req = Dancer2::Core::Request->new(
        env         => psgi_env( query => 'x=%FF%FE' ),
        strict_utf8 => 1,
    );

    my $err = exception { $req->params->{x} };
    ok( defined $err, 'reading the parameter throws' );
    like( $err, qr/Invalid UTF-8 in query parameters/,
        'naming what was invalid and where' );
    unlike( $err, qr/leaving bytes unchanged/,
        'and not claiming to have carried on' );

    # Valid UTF-8 is unaffected by strict mode.
    my $ok = Dancer2::Core::Request->new(
        env         => psgi_env( query => 'x=%C3%A9' ),
        strict_utf8 => 1,
    );
    is( $ok->params->{x}, "\x{e9}",
        'valid UTF-8 still decodes normally under strict_utf8' );
};

subtest 'the XS and pure-Perl query parsers agree' => sub {
    # This distribution must stay usable with no XS modules installed
    # (CLAUDE.md: "core must stay pure-Perl-loadable"), so both parsers have
    # to produce the same result. Whichever one is active on this machine,
    # the other is still exercised here.
    #
    # CGI::Deurl::XS is optional. Forcing $XS_PARSE_QUERY_STRING on below
    # calls CGI::Deurl::XS::parse_query_string() directly, which dies with
    # "Undefined subroutine" if the module was never loaded - so skip
    # outright rather than let that take the rest of the file down with it.
    unless ( eval { require CGI::Deurl::XS; 1 } ) {
        plan skip_all => 'CGI::Deurl::XS is not installed';
    }

    my $query = 'a=1&a=2&plus=a+b&utf=%C3%A9&empty=&solo=x';

    my %result;
    for my $mode ( [ xs => 1 ], [ pp => 0 ] ) {
        my ( $label, $on ) = @$mode;

        no warnings 'once';
        local $Dancer2::Core::Request::XS_PARSE_QUERY_STRING = $on;
        local $Dancer2::Core::Request::XS_URL_DECODE         = $on;

        my $req = Dancer2::Core::Request->new( env => psgi_env( query => $query ) );
        $result{$label} = $req->params;
    }

    is_deeply( $result{pp}, $result{xs},
        'both parsers produce identical parameters for the same query string' );

    # Spot-check the things a hand-rolled parser gets wrong, so this is not
    # just "two broken parsers agree".
    for my $label ( 'xs', 'pp' ) {
        my $p = $result{$label};
        is_deeply( $p->{a}, [ '1', '2' ], "$label: repeated name becomes a list" );
        is( $p->{plus}, 'a b',      "$label: '+' decodes to a space" );
        is( $p->{utf},  "\x{e9}",   "$label: percent-encoded UTF-8 decodes" );
        is( $p->{empty}, '',        "$label: a name with no value is the empty string" );
        is( $p->{solo}, 'x',        "$label: an ordinary pair survives" );
    }
};

subtest 'splat and captures stay out of route_parameters' => sub {
    my $req = Dancer2::Core::Request->new( env => psgi_env( query => 'q=1' ) );

    # App::_dispatch passes the *same* hashref to both setters, in this order,
    # and the second one deletes splat/captures from it. So the order is
    # load-bearing: reversed, splat() below would come back empty.
    my $match = { id => '42', splat => [ 'a', 'b' ], captures => { name => 'x' } };
    $req->_set_route_params($match);
    $req->_set_route_parameters($match);

    # The legacy hash keeps them - that is how splat() and captures() work.
    is_deeply( [ $req->splat ], [ 'a', 'b' ], 'splat() returns the captures' );
    is_deeply( $req->captures, { name => 'x' }, 'captures() returns the named ones' );

    # The Hash::MultiValue accessors must not carry them, or an application
    # iterating its route parameters would see reserved names as user data.
    is_deeply( [ sort $req->route_parameters->keys ], ['id'],
        'route_parameters holds only the real named parameter' );
    is_deeply( [ sort $req->parameters->keys ], [ 'id', 'q' ],
        'and neither does the merged view' );

    is( $req->route_parameters->get('id'), '42',
        'the named route parameter is still readable' );
};

subtest 'a forwarded request keeps its decoded body parameters' => sub {
    my $req = form_request(
        method => 'POST',
        query  => 'from=query',
        body   => 'name=%C3%A9t%C3%A9&keep=yes',
    );

    my $before = $req->body_parameters->get('name');
    ok( utf8::is_utf8($before), 'the original body parameter is decoded' );

    # What App::make_forward_to does: clone with extra params and a new path.
    my $clone = $req->_shallow_clone( { added => 'new' }, { PATH_INFO => '/dst' } );

    # The regression this guards (GH#1116, GH#1269): the clone used to lose
    # already-decoded body parameters, or decode them a second time.
    my $after = $clone->body_parameters->get('name');
    ok( utf8::is_utf8($after), 'the clone still has it decoded' );
    is( $after, $before, 'with the same value, not double-decoded' );
    is_deeply( [ sort $clone->body_parameters->keys ], [ 'keep', 'name' ],
        'and every body parameter came across' );

    # The legacy per-source view is carried by its own line in _shallow_clone,
    # separate from both the Hash::MultiValue clone above and the merged
    # params below. Dropping it leaves params('body') empty while those two
    # still look right, so it needs asserting in its own right.
    my $clone_body = $clone->params('body');
    is_deeply( [ sort keys %$clone_body ], [ 'keep', 'name' ],
        "params('body') on the clone still lists every body parameter" );
    is( $clone_body->{keep}, 'yes', "and their values" );
    is( $clone_body->{name}, $before,
        "still decoded, matching the original request" );

    is( $clone->params->{keep},  'yes', 'body parameters are in the clone params' );
    is( $clone->params->{from},  'query', 'so are query parameters' );
    is( $clone->params->{added}, 'new', 'and the parameters added at forward time' );
    is( $clone->query_parameters->get('added'), 'new',
        'the added parameters also reach query_parameters' );

    is( $clone->env->{PATH_INFO}, '/dst', 'the clone has the new path' );
    is( $req->env->{PATH_INFO}, '/',
        'and the original request is not modified by the clone' );
};

done_testing();
