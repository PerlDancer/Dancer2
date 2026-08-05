use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;

use Dancer2::Logger::Capture;

# Which messages get through, and what a message turns into on the way.
#
# The level table in Dancer2::Core::Role::Logger puts 'core' at -10 and the
# user-facing levels at 1..4, and _should is a single numeric comparison:
#
#     $levels->{configured} <= $levels->{message}
#
# So 'core' is below every user level by construction, and the only way to see
# core messages is to configure log_level: core. That is what keeps Dancer2's
# own internal chatter ("looking for get /", "Entering hook ...") out of an
# application's log.
#
# Dancer2::Logger::Capture is used as the engine: it stores messages instead of
# printing them and ships as a supported part of this distribution, so no
# stand-in is involved.

my @LEVELS = qw< core debug info warning error >;

sub logger_at {
    my $level = shift;
    return Dancer2::Logger::Capture->new( log_level => $level, config => {} );
}

# Emit one message at every level, return the levels that actually got through.
sub emitted_under {
    my $configured = shift;
    my $logger     = logger_at($configured);

    $logger->$_("message-at-$_") for @LEVELS;

    return [ map { $_->{level} } @{ $logger->trapper->read } ];
}

subtest 'a level lets through itself and everything above it' => sub {
    # Written out in full rather than computed, so the expectation is readable
    # and a change has to be made deliberately.
    my %expected = (
        core    => [qw< core debug info warning error >],
        debug   => [qw< debug info warning error >],
        info    => [qw< info warning error >],
        warning => [qw< warning error >],
        error   => [qw< error >],
    );

    for my $configured ( @LEVELS ) {
        is_deeply( emitted_under($configured), $expected{$configured},
            "log_level '$configured' emits exactly @{$expected{$configured}}" );
    }
};

subtest 'core messages are hidden from every user-facing level' => sub {
    # The point of the negative level. Dancer2 logs its own dispatch trace at
    # core, and an application that asked for debug must not receive it.
    for my $configured ( qw< debug info warning error > ) {
        my $got = emitted_under($configured);
        ok( !grep( { $_ eq 'core' } @$got ),
            "log_level '$configured' does not emit core messages" );
    }

    # And the control: they are not simply never emitted.
    my $got = emitted_under('core');
    ok( scalar grep( { $_ eq 'core' } @$got ),
        "log_level 'core' does emit them" );
};

subtest 'warn is accepted as a synonym for warning' => sub {
    # 'warn' is in the level table at the same value as 'warning', so it is a
    # legal log_level even though there is no warn() method.
    my $logger = logger_at('warn');

    $logger->debug('below');
    $logger->warning('at');
    $logger->error('above');

    is_deeply( [ map { $_->{level} } @{ $logger->trapper->read } ],
        [ 'warning', 'error' ],
        "log_level 'warn' filters exactly as 'warning' does" );
};

subtest 'an unknown level is refused at construction' => sub {
    # Better than silently defaulting: a typo in the config is fatal rather
    # than quietly turning logging up or off.
    my $err = exception {
        Dancer2::Logger::Capture->new( log_level => 'verbose', config => {} );
    };

    ok( defined $err, "log_level 'verbose' is refused" );
    like( $err, qr/verbose/, 'and the value is named in the error' );

    # Every level in the table is accepted, including the synonym.
    for my $level ( @LEVELS, 'warn' ) {
        is( exception {
                Dancer2::Logger::Capture->new( log_level => $level, config => {} )
            },
            undef,
            "log_level '$level' is accepted",
        );
    }
};

subtest 'message arguments are serialised for logging' => sub {
    my $logger = Dancer2::Logger::Capture->new(
        log_format => '[%m]',
        config     => {},
    );

    # A trailing newline is chomped, so a log line is not double-spaced.
    $logger->info("trailing newline\n");

    # A reference is dumped compactly, with keys sorted so the output is
    # deterministic.
    $logger->info( { b => 2, a => 1 } );

    # Several arguments are concatenated, and undef becomes the string 'undef'
    # rather than triggering a warning.
    $logger->info( 'x', 'y', undef );

    my @formatted = map { $_->{formatted} } @{ $logger->trapper->read };
    chomp @formatted;

    is( $formatted[0], '[trailing newline]',
        'a trailing newline is removed from the message' );
    is( $formatted[1], "[{'a' => 1,'b' => 2}]",
        'a hashref is dumped on one line with sorted keys' );
    is( $formatted[2], '[xyundef]',
        'multiple arguments concatenate and undef becomes "undef"' );
};

subtest 'a formatted line always ends with a newline' => sub {
    # The engines write the formatted string as-is, so the trailing newline has
    # to come from format_message.
    my $logger = Dancer2::Logger::Capture->new(
        log_format => '%L: %m',
        config     => {},
    );

    $logger->info('no newline');
    $logger->info("one newline\n");
    $logger->info("two newlines\n\n");
    $logger->info("newline\nin the middle");

    my @formatted = map { $_->{formatted} } @{ $logger->trapper->read };

    like( $_, qr/\n\z/, 'the line ends with a newline' ) for @formatted;

    is( $formatted[0], "info: no newline\n",
        'a message with no newline gets exactly one' );
    is( $formatted[1], "info: one newline\n",
        'a message with one trailing newline still gets exactly one' );

    # chomp removes a single trailing newline, so a message that ended with two
    # produces a blank line. Pinned as current behavior: it is a cosmetic wart,
    # not a correctness problem, and the fix would be a chomp-while loop.
    is( $formatted[2], "info: two newlines\n\n",
        'a message ending in two newlines leaves a blank line behind' );

    # An interior newline is untouched - only the trailing one is chomped.
    is( $formatted[3], "info: newline\nin the middle\n",
        'a newline inside the message is left alone' );
};

done_testing();
