use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;

use Dancer2::Core::Cookie;
use Dancer2::Core::Time;

# Cookie header generation and the time expressions that feed the Expires
# attribute.
#
# Time expressions come in two kinds, and the difference is easy to get wrong:
#
#   a bare digit string  -> an absolute Unix epoch
#   anything else        -> an offset from now ("2 hours", "1h30m", "1w")
#
# So expires => 3600 is 1 Jan 1970, not "in an hour". That is what
# Dancer2::Core::Cookie's own documentation says ("Unix epoch time like
# 1288817656 ... It also supports a human readable offset from the current time
# such as '2 hours'"), and Dancer2::Core::Session compensates for it by adding
# time() before handing the value over. Both halves are pinned below.
#
# Absolute epochs are used wherever an exact string is asserted, so no clock
# needs faking. 1288817656 is the value from the module's own POD, together
# with the string that POD says it produces.

my $POD_EPOCH  = 1288817656;
my $POD_STRING = 'Wed, 03-Nov-2010 20:54:16 GMT';

sub header_for {
    return Dancer2::Core::Cookie->new(@_)->pp_to_header;
}

# --- time expressions ----------------------------------------------------

subtest 'a bare number is an absolute epoch' => sub {
    my $time = Dancer2::Core::Time->new( expression => $POD_EPOCH );

    is( $time->epoch, $POD_EPOCH, 'the epoch is the number itself' );
    is( $time->gmt_string, $POD_STRING,
        'and formats to the string the documentation promises' );

    # Not time() + 1288817656, which is what treating it as an offset would
    # give. Asserted explicitly because it is the confusing half.
    cmp_ok( $time->epoch, '<', time,
        'a 2010 epoch stays in the past rather than being added to now' );

    # The consequence, stated plainly: a number that looks like a duration is
    # interpreted as an epoch in 1970.
    is( Dancer2::Core::Time->new( expression => 3600 )->gmt_string,
        'Thu, 01-Jan-1970 01:00:00 GMT',
        'expires => 3600 means one hour after the epoch, not one hour from now' );
};

subtest 'a human-readable expression is an offset from now' => sub {
    my $now = time;

    my %offset = (
        '1s'       => 1,
        '1m'       => 60,
        '1h'       => 3600,
        '2 hours'  => 7200,
        '1d'       => 86400,
        '1w'       => 604800,
        '1y'       => 31536000,
        '1h30m'    => 5400,
        '1.5h'     => 5400,
        '01:30'    => 5400,
        '01:30:00' => 5400,
    );

    for my $expression ( sort keys %offset ) {
        my $seconds = $offset{$expression};
        my $time    = Dancer2::Core::Time->new( expression => $expression );

        is( $time->seconds, $seconds,
            "'$expression' is $seconds seconds" );

        # The epoch is now + seconds. Allowing a few seconds of slack keeps
        # this from being flaky if the clock ticks mid-test.
        cmp_ok( $time->epoch, '>=', $now + $seconds,
            "'$expression' resolves to a time at least that far ahead" );
        cmp_ok( $time->epoch, '<=', $now + $seconds + 10,
            "'$expression' resolves to a time not much further ahead" );
    }

    # 'M' is months and 'm' is minutes: single-character units are not
    # lower-cased, and confusing them is a factor of 43200.
    is( Dancer2::Core::Time->new( expression => '1M' )->seconds, 2592000,
        'a capital M is one month' );
    is( Dancer2::Core::Time->new( expression => '1m' )->seconds, 60,
        'while a lower-case m is one minute' );

    # A negative offset is how a cookie is expired in the past - this is what
    # destroy_session relies on.
    my $past = Dancer2::Core::Time->new( expression => -86400 );
    is( $past->seconds, -86400, 'a negative expression stays negative' );
    cmp_ok( $past->epoch, '<', time, 'and resolves to a time in the past' );
};

subtest 'an unparseable expression is passed through unchanged' => sub {
    # Deliberate: Dancer2::Core::Time documents that "anything else is used
    # verbatim". Silently turning it into a wrong date would be worse - the
    # value reaches the header where it is visible.
    for my $expression ( 'not a time', '3 fortnights', '2 hours and cheese' ) {
        my $time = Dancer2::Core::Time->new( expression => $expression );

        is( $time->seconds,    $expression, "'$expression': seconds is verbatim" );
        is( $time->epoch,      $expression, "'$expression': epoch is verbatim" );
        is( $time->gmt_string, $expression, "'$expression': gmt_string is verbatim" );
    }

    # A partially-valid expression is rejected whole, not silently truncated
    # to the part that parsed.
    isnt( Dancer2::Core::Time->new( expression => '2 hours and cheese' )->seconds,
        7200, 'the parseable prefix of a bad expression is not used on its own' );
};

# --- cookie headers ------------------------------------------------------

subtest 'a minimal cookie gets a path and HttpOnly' => sub {
    is( header_for( name => 'n', value => 'v' ), 'n=v; Path=/; HttpOnly',
        'name, value, the default path, and HttpOnly' );
};

subtest 'every attribute reaches the header' => sub {
    my $header = header_for(
        name      => 'sid',
        value     => 'abc',
        path      => '/app',
        domain    => '.example.com',
        expires   => $POD_EPOCH,
        same_site => 'Strict',
        secure    => 1,
        http_only => 1,
    );

    # Asserted as one exact string: it pins the attribute order too, which a
    # set of independent regexes would not.
    is(
        $header,
        "sid=abc; Path=/app; Expires=$POD_STRING; Domain=.example.com;"
            . ' SameSite=Strict; Secure; HttpOnly',
        'all attributes are present, in order',
    );

    # And individually, so a failure says which one went missing.
    like( $header, qr/\bPath=\/app\b/,             'Path' );
    like( $header, qr/\bExpires=\Q$POD_STRING\E/,  'Expires' );
    like( $header, qr/\bDomain=\.example\.com\b/,  'Domain' );
    like( $header, qr/\bSameSite=Strict\b/,        'SameSite' );
    like( $header, qr/\bSecure\b/,                 'Secure' );
    like( $header, qr/\bHttpOnly\b/,               'HttpOnly' );
};

subtest 'the boolean attributes are omitted rather than negated' => sub {
    # There is no "Secure=0" in HTTP - a false flag means the attribute is
    # absent.
    unlike( header_for( name => 'n', value => 'v', secure => 0 ), qr/Secure/,
        'secure => 0 omits Secure' );
    like( header_for( name => 'n', value => 'v', secure => 1 ), qr/; Secure\b/,
        'secure => 1 emits it' );

    unlike( header_for( name => 'n', value => 'v', http_only => 0 ), qr/HttpOnly/,
        'http_only => 0 omits HttpOnly' );
    like( header_for( name => 'n', value => 'v', http_only => 1 ), qr/HttpOnly/,
        'http_only => 1 emits it' );

    # HttpOnly is on by default, so leaving it out is not the same as
    # turning it off.
    like( header_for( name => 'n', value => 'v' ), qr/HttpOnly/,
        'HttpOnly is emitted when nothing was said about it' );

    # A falsy path is omitted too.
    unlike( header_for( name => 'n', value => 'v', path => '' ), qr/Path/,
        'an empty path omits the Path attribute' );
};

subtest 'same_site only accepts the values the standard defines' => sub {
    for my $value (qw< Strict Lax None >) {
        like( header_for( name => 'n', value => 'v', same_site => $value ),
            qr/\bSameSite=$value\b/, "SameSite=$value is accepted" );
    }

    # A typo is refused at construction rather than emitted as a header a
    # browser would ignore.
    ok(
        defined exception {
            Dancer2::Core::Cookie->new(
                name => 'n', value => 'v', same_site => 'strict' )
        },
        'a lower-case value is refused',
    );
    ok(
        defined exception {
            Dancer2::Core::Cookie->new(
                name => 'n', value => 'v', same_site => 'Nonsense' )
        },
        'and so is a value that is not in the enum',
    );
};

subtest 'a multi-value cookie keeps every value, escaped' => sub {
    is( header_for( name => 'n', value => [ 'a', 'b', 'c' ] ),
        'n=a&b&c; Path=/; HttpOnly',
        'values are joined with an ampersand' );

    # Each value is escaped individually, so a separator inside a value cannot
    # be mistaken for a separator between values.
    is( header_for( name => 'n', value => [ 'a b', 'c;d' ] ),
        'n=a%20b&c%3Bd; Path=/; HttpOnly',
        'each value is URI-escaped on its own' );

    # A single value with every character that would otherwise confuse a
    # parser.
    is( header_for( name => 'n', value => 'a b;c,d=e&f' ),
        'n=a%20b%3Bc%2Cd%3De%26f; Path=/; HttpOnly',
        'space, semicolon, comma, equals and ampersand are all escaped' );

    my $cookie = Dancer2::Core::Cookie->new( name => 'n', value => [ 'a', 'b' ] );
    is_deeply( [ $cookie->value ], [ 'a', 'b' ],
        'the accessor returns every value in list context' );
    is_deeply( [ $cookie->values ], [ 'a', 'b' ],
        'and values() does the same' );
    is( scalar $cookie->value, 'a',
        'while scalar context gives the first' );
    is( "$cookie", 'a',
        'and stringification gives the first, per the documented overload' );
};

subtest 'an unparseable expires reaches the header verbatim' => sub {
    # Following from the Time behavior above: the bad value is visible in the
    # header rather than being turned into a plausible-looking wrong date.
    my $header = header_for( name => 'n', value => 'v', expires => 'not a time' );

    is( $header, 'n=v; Path=/; Expires=not a time; HttpOnly',
        'the expression appears as given' );
    unlike( $header, qr/1970|GMT/,
        'and is not converted into a date' );
};

subtest 'the XS header builder agrees with the pure-Perl one' => sub {
    # Dancer2::Core::Cookie picks one of two implementations at load time and
    # aliases to_header to it. Both must produce the same header, or which
    # optional modules happen to be installed changes the response.
  SKIP: {
        skip 'HTTP::XSCookies is not installed, so xs_to_header cannot run', 3
            if !Dancer2::Core::Cookie::_USE_XS();

        my %args = (
            name      => 'sid',
            value     => 'abc',
            path      => '/app',
            expires   => $POD_EPOCH,
            secure    => 1,
            http_only => 1,
        );
        my $cookie = Dancer2::Core::Cookie->new(%args);

        my $xs = $cookie->xs_to_header;
        like( $xs, qr/^sid=abc/,  'the XS builder emits the name and value' );
        like( $xs, qr/\bSecure\b/, 'and the Secure attribute' );

        # Multi-value cookies are explicitly delegated to the pure-Perl
        # builder, so those must match exactly.
        my $multi = Dancer2::Core::Cookie->new(
            name => 'n', value => [ 'a', 'b' ] );
        is( $multi->xs_to_header, $multi->pp_to_header,
            'a multi-value cookie is delegated to the pure-Perl builder' );
    }

    # Whichever implementation is active, to_header must be one of the two -
    # asserted unconditionally so this subtest is never vacuous.
    my $cookie = Dancer2::Core::Cookie->new( name => 'n', value => 'v' );
    my $expected = Dancer2::Core::Cookie::_USE_XS()
        ? $cookie->xs_to_header
        : $cookie->pp_to_header;
    is( $cookie->to_header, $expected,
        'to_header is aliased to the implementation this build selected' );
};

done_testing();
