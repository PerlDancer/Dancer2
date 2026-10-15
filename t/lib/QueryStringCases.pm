package QueryStringCases;

use strict;
use warnings;

use Exporter 'import';
use Test::More;

use Dancer2::Core::Request;

our @EXPORT_OK = qw< check_query_string_cases >;

# Each query string with the hash that both params() and query_parameters()
# must give for it. One expectation serves both: params() has the shape that
# Hash::MultiValue's as_hashref_mixed() returns, a flat hash with an arrayref
# for a repeated name.
my @CASES = (
    [ 'a=1&a=2' => { a => [ 1, 2 ] }, 'a repeated name keeps every value' ],
    [ 'plus=a+b'   => { plus => 'a b' },    "'+' decodes to a space" ],
    [ 'utf=%C3%A9' => { utf  => "\x{e9}" }, 'percent-encoded UTF-8 decodes' ],
    [   'empty=&solo=x' => { empty => '', solo => 'x' },
        'a name with no value is the empty string'
    ],
    [   'state=YWJjZA==' => { state => 'YWJjZA==' },
        'base64 padding survives (GH #1806)'
    ],
    [ 'nul=a%00b' => { nul    => "a\0b" }, '%00 does not cut a value short' ],
    [ 'n%00x=1'   => { "n\0x" => 1 },      '%00 does not cut a name short' ],
    [ 'a=1;b=2' => { a => 1, b => 2 }, "';' separates pairs" ],
    [   'm=1&m=2;s=x' => { m => [ 1, 2 ], s => 'x' },
        "'&' and ';' mixed, with a repeated name"
    ],
    [ '%zz=%4' => { '%zz' => '%4' }, 'a malformed escape is left as it is' ],
    [ 'a=1&' => { a => 1, '' => '' }, 'a trailing empty pair gives a blank name' ],
    [   'a&&b=1' => { a => '', '' => '', b => 1 },
        'an empty pair in the middle gives a blank name'
    ],
    [ '&' => { '' => [ '', '' ] }, "a lone '&' is two empty pairs" ],
    [ ''  => {},                   'no query string, no parameters' ],
);

sub _request {
    my $query = shift;
    open my $input, '<', \( my $body = '' ) or die "cannot open body: $!";
    return Dancer2::Core::Request->new( env => {
        REQUEST_METHOD    => 'GET',
        PATH_INFO         => '/',
        QUERY_STRING      => $query,
        SCRIPT_NAME       => '',
        SERVER_NAME       => 'localhost',
        SERVER_PORT       => 80,
        CONTENT_LENGTH    => 0,
        'psgi.url_scheme' => 'http',
        'psgi.input'      => $input,
        'psgi.errors'     => \*STDERR,
    } );
}

sub check_query_string_cases {
    for my $case (@CASES) {
        my ( $query, $expected, $what ) = @{$case};

        # A fresh request per accessor, so neither reads the other's cache.
        is_deeply( { _request($query)->params }, $expected, "params: $what" );
        is_deeply( _request($query)->query_parameters->as_hashref_mixed,
            $expected, "query_parameters: $what" );
    }

    is_deeply( scalar _request('')->params('query'), {},
        "params('query') is an empty hashref when there is no query string" );
}

1;
