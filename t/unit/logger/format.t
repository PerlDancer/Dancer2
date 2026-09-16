use strict;
use warnings;

use Test::More;

use Dancer2::Logger::Capture;
use Dancer2::Core::Request;

# log_format substitution. Two syntaxes share one regex
# (Dancer2/Core/Role/Logger.pm:110-116):
#
#   %X          a single-character code, looked up in map_chars_to_subs
#   %{thing}X   a block code, handled by the block handler (only t and h)
#
# An unrecognised code in either syntax must warn and render '-' rather than
# abort the log call: losing a log line because its format string has a typo in
# it would be a poor trade.
#
# format_message is called directly rather than through a request, because the
# substitutions are what is under test and a full dispatch would add nothing.

my $REQUEST = do {
    my $body = '';
    open my $input, '<', \$body or die "cannot open in-memory body: $!";

    Dancer2::Core::Request->new(
        env => {
            REQUEST_METHOD    => 'GET',
            PATH_INFO         => '/some/path',
            QUERY_STRING      => '',
            SCRIPT_NAME       => '',
            SERVER_NAME       => 'localhost',
            SERVER_PORT       => 80,
            CONTENT_LENGTH    => 0,
            REMOTE_ADDR       => '10.0.0.9',
            HTTP_USER_AGENT   => 'TestAgent/1.0',
            HTTP_X_CUSTOM     => 'CUSTOM-HEADER-VALUE',
            'psgi.url_scheme' => 'http',
            'psgi.input'      => $input,
            'psgi.errors'     => \*STDERR,
        },
    );
};

# Format one message with the given format string, returning the rendered line
# and any warnings it produced.
sub render {
    my ( $format, %opt ) = @_;

    my $logger = Dancer2::Logger::Capture->new(
        log_format => $format,
        app_name   => 'MyApp',
        config     => {},
        ( exists $opt{caller_stack_size}
            ? ( caller_stack_size => $opt{caller_stack_size} ) : () ),
    );
    $logger->set_request($REQUEST) unless $opt{no_request};

    my @warnings;
    my $line = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        $logger->format_message( 'warning', 'THE-MESSAGE' );
    };
    chomp $line;

    return ( $line, \@warnings );
}

sub rendered { my ($line) = render(@_); return $line }

subtest 'the message, level and app name substitute' => sub {
    is( rendered('%m'), 'THE-MESSAGE', '%m is the message' );
    is( rendered('%L'), 'warning',     '%L is the level' );
    is( rendered('%a'), 'MyApp',       '%a is the app name' );
    is( rendered('%P'), $$,            '%P is the process id' );

    # Surrounding literal text is preserved, and several codes can appear in
    # one format.
    is( rendered('[%L] %m (%a)'), '[warning] THE-MESSAGE (MyApp)',
        'codes substitute in place, literals are kept' );

    # An app that set no name gets the documented default.
    my $unnamed = Dancer2::Logger::Capture->new(
        log_format => '%a', config => {} );
    is( $unnamed->format_message( 'info', 'x' ), "-\n",
        'the app name defaults to "-"' );
};

subtest 'the request-derived codes substitute' => sub {
    is( rendered('%h'), '10.0.0.9',
        '%h is the host that made the request' );
    is( rendered('%i'), $REQUEST->id,
        '%i is the request id' );

    # With no request attached, both fall back rather than dying.
    is( rendered( '%h', no_request => 1 ), '-',
        '%h is "-" when there is no request' );
    is( rendered( '%i', no_request => 1 ), '-',
        '%i is "-" when there is no request' );
};

subtest 'the date codes substitute in their documented formats' => sub {
    # The exact instant is not asserted - only the shape, which is what
    # distinguishes the four codes from each other.
    like( rendered('%t'), qr{^\d{2}/[A-Z][a-z]{2}/\d{4} \d{2}:\d{2}:\d{2}$},
        '%t is dd/Mon/yyyy hh:mm:ss' );
    like( rendered('%T'), qr{^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$},
        '%T is yyyy-mm-dd hh:mm:ss' );
    like( rendered('%u'), qr{^\d{2}/[A-Z][a-z]{2}/\d{4} \d{2}:\d{2}:\d{2}$},
        '%u is dd/Mon/yyyy hh:mm:ss, in UTC' );
    like( rendered('%U'), qr{^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$},
        '%U is yyyy-mm-dd hh:mm:ss, in UTC' );
};

subtest 'the caller codes substitute from the stack' => sub {
    # caller_stack_size decides which frame %p, %f and %l report. It defaults
    # to 9, which is where the frame sits when the call came through a route;
    # calling format_message directly here means that frame does not exist, so
    # the codes fall back to '-'.
    is( rendered('%p|%f|%l'), '-|-|-',
        'the codes are "-" when the configured frame is off the top of the stack' );

    # Pointed at a frame that does exist, they substitute for real. This is
    # what shows the codes are wired up and not simply always '-'.
    my $line = rendered( '%p|%f|%l', caller_stack_size => 1 );
    my ( $package, $file, $lineno ) = split /\|/, $line;

    is( $package, 'main', '%p is the calling package' );
    like( $file, qr/format\.t$/, '%f is the calling file' );
    like( $lineno, qr/^\d+$/, '%l is a line number' );
};

subtest 'a %{...}h block reads the named request header' => sub {
    is( rendered('%{X-Custom}h'), 'CUSTOM-HEADER-VALUE',
        'a custom header is read by name' );
    is( rendered('%{User-Agent}h'), 'TestAgent/1.0',
        'and so is a standard one' );

    # A header that is not present renders '-' rather than the empty string, so
    # the field stays visible in the log line.
    is( rendered('%{X-Missing}h'), '-',
        'an absent header renders as "-"' );

    is( rendered( '%{X-Custom}h', no_request => 1 ), '-',
        'and so does any header when there is no request' );
};

subtest 'a %{...}t block is a strftime format' => sub {
    is( rendered('%{%Y}t'), POSIX::strftime( '%Y', localtime(time) ),
        'the block is passed to strftime' );
    like( rendered('%{%Y-%m}t'), qr/^\d{4}-\d{2}$/,
        'a multi-part format works too' );
};

subtest 'an unrecognised code warns and renders "-"' => sub {
    # The log call must survive. A format string with a typo should degrade the
    # one field, not lose the message.
    my ( $line, $warnings ) = render('%Z');

    is( $line, '-', 'the unknown code renders as "-"' );
    is( scalar @$warnings, 1, 'and warns once' );
    like( $warnings->[0], qr/%Z not supported/,
        'naming the code that was not recognised' );

    # The rest of the format still renders, which is the part that matters:
    # the message is not lost.
    my ( $mixed, $mixed_warnings ) = render('%L|%Z|%m');
    is( $mixed, 'warning|-|THE-MESSAGE',
        'the surrounding codes still substitute' );
    is( scalar @$mixed_warnings, 1, 'with one warning for the bad code' );
};

subtest 'an unrecognised block type warns and renders "-"' => sub {
    my ( $line, $warnings ) = render('%{whatever}z');

    is( $line, '-', 'the unknown block renders as "-"' );
    is( scalar @$warnings, 1, 'and warns once' );
    like( $warnings->[0], qr/\{whatever\}z not supported/,
        'naming the block and its type' );
};

subtest 'an unsupported format character behaves the same whether or not it was ever documented' => sub {

    # %D used to be listed in the log_format POD ("timer") despite
    # map_chars_to_subs never implementing it. Rather than invent a timer
    # with no state in the logger role to back it, the fix was to remove %D
    # from the docs, so it is now just another unsupported character. This
    # checks it is indistinguishable from %Z, which was never documented at
    # all: both warn once per logged message and render '-'.
    for my $char (qw(D Z)) {
        my ( $line, $warnings ) = render("%$char");

        is( $line, '-', "%$char renders as \"-\"" );
        is( scalar @$warnings, 1, "%$char warns once per logged message" );
        like( $warnings->[0], qr/%\Q$char\E not supported/,
            "the warning names %$char" );
    }

    # The comparison that makes the point: a once-documented code and one that
    # was never documented are treated identically.
    my ( $d_line ) = render('%D');
    my ( $z_line ) = render('%Z');
    is( $d_line, $z_line, '%D behaves exactly like %Z' );
};

subtest 'every documented format character renders without warning' => sub {
    # The flip side of the subtest above: every character actually listed in
    # the log_format POD must resolve through map_chars_to_subs (or the block
    # handler), never fall through to the unsupported-code path. If this list
    # and the POD list ever drift apart, this is where it shows up.
    for my $char (qw(a h t T u U P L m p f l i)) {
        my ( undef, $warnings ) = render("%$char");
        is( scalar @$warnings, 0, "%$char does not warn" );
    }

    # The two block forms take an argument, so they are exercised separately
    # from the single-character codes above.
    for my $block ( '%{X-Custom}h', '%{%Y}t' ) {
        my ( undef, $warnings ) = render($block);
        is( scalar @$warnings, 0, "$block does not warn" );
    }
};

subtest 'the default log_format renders every one of its parts' => sub {
    # '[%a:%P] %L @%T> %m in %f l. %l' - the default. Rendered with a stack
    # size that resolves, so no part is '-' for reasons unrelated to the format.
    my $logger = Dancer2::Logger::Capture->new(
        app_name          => 'MyApp',
        caller_stack_size => 1,
        config            => {},
    );
    $logger->set_request($REQUEST);

    my $line = $logger->format_message( 'warning', 'THE-MESSAGE' );
    chomp $line;

    like(
        $line,
        qr{^
            \[MyApp:$$\]\             # [%a:%P]
            warning\ @                # %L @
            \d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2}>\   # %T>
            THE-MESSAGE\ in\          # %m in
            \S+format\.t\ l\.\ \d+    # %f l. %l
        $}x,
        'the default format renders as documented, with no unsubstituted codes',
    );

    unlike( $line, qr/%[a-zA-Z]/, 'no format code is left unsubstituted' );
    unlike( $line, qr/(?<![\w.])-(?![\w-])/, 'and no field fell back to "-"' );
};

done_testing();
