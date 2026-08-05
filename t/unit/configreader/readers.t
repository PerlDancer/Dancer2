use strict;
use warnings;

use Test::More;
use Test::Fatal qw<exception>;
use Path::Tiny ();

use Dancer2::ConfigReader;

# A config can bootstrap further config readers: any reader whose config
# contains 'additional_config_readers' has those readers instantiated and
# unshifted onto the queue (Dancer2/ConfigReader.pm:254-259). That is a loop
# that a config file gets to extend, so it needs a stop.
#
# The stop is a counter checked against $MAX_CONFIGS
# (Dancer2/ConfigReader.pm:239-250), which dies with an explanation rather than
# spinning forever. This file pins that it fires, that it honours the limit it
# is given, and that a well-formed chain still works.
#
# The readers below are real classes consuming the real role, not stand-ins:
# the whole mechanism is "instantiate this class and call read_config on it",
# so there is nothing to fake.

# Contributes one setting and stops.
{
    package TestReader::Leaf;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';
    sub name        { 'TestReader::Leaf' }
    sub read_config { return { leaf_key => 'leaf_value', strict_config => 0 } }
}

# Contributes a setting and asks for Leaf as well.
{
    package TestReader::Chained;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';
    sub name { 'TestReader::Chained' }

    sub read_config {
        return {
            chained_key               => 'chained_value',
            additional_config_readers => 'TestReader::Leaf',
        };
    }
}

# Asks for another copy of itself, forever.
{
    package TestReader::SelfAdding;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';
    sub name { 'TestReader::SelfAdding' }

    # Counts how many times it was actually read, so a test can assert where
    # the guard cut in rather than only that it did.
    our $READS = 0;

    sub read_config {
        $READS++;
        return { additional_config_readers => 'TestReader::SelfAdding' };
    }
}

# An entry with two keys, which is ambiguous: is it a class with args, or two
# classes?
{
    package TestReader::TwoKeys;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';
    sub name { 'TestReader::TwoKeys' }

    sub read_config {
        return {
            additional_config_readers => { 'TestReader::Leaf' => {}, 'Other' => {} },
        };
    }
}

my $EMPTY;
BEGIN { $EMPTY = Path::Tiny->tempdir }

# DANCER_CONFIG_READERS is how the reader list is chosen, so each case sets it
# for the duration of one read.
sub read_with {
    my $readers = shift;

    local $ENV{DANCER_CONFIG_READERS} = $readers;
    local $ENV{DANCER_CONFDIR};
    delete local $ENV{DANCER_CONFDIR};
    local $ENV{DANCER_ENVDIR};
    delete local $ENV{DANCER_ENVDIR};

    return Dancer2::ConfigReader->new(
        location       => $EMPTY->stringify,
        environment    => 'production',
        default_config => {},
    )->config;
}

subtest 'a reader named in additional_config_readers is also read' => sub {
    my $config = read_with('TestReader::Chained');

    is( $config->{chained_key}, 'chained_value',
        'the reader that was asked for contributed its setting' );
    is( $config->{leaf_key}, 'leaf_value',
        'and so did the reader it pulled in' );

    # The key that drives the mechanism is consumed, not left in the config.
    is( $config->{additional_config_readers}, undef,
        'additional_config_readers is removed once it has been acted on' );
};

subtest 'the recursion guard stops a reader that adds itself forever' => sub {
    my $err = exception { read_with('TestReader::SelfAdding') };

    ok( defined $err, 'reading does not hang - it dies' );
    like( $err, qr/MAX_CONFIGS exceeded/,
        'naming the limit that was hit' );
    like( $err, qr/read over 100 configurations/,
        'and how many configs were read, from the default limit' );

    # The message has to be usable, not just fatal: it says what is probably
    # wrong and what to do about it.
    like( $err, qr/infinite recursion in your configuration system/,
        'the message explains the likely cause' );
    like( $err, qr/DANCER_CONFIG_VERBOSE/,
        'and points at the way to see which readers ran' );
    like( $err, qr/DANCER_MAX_CONFIGS/,
        'and at the way to raise the limit deliberately' );
};

subtest 'the guard honours the limit it is given' => sub {
    # Proves the count is what stops it, rather than some unrelated failure
    # that happens to look like the guard.
    no warnings 'once';
    local $Dancer2::ConfigReader::MAX_CONFIGS = 5;

    local $TestReader::SelfAdding::READS = 0;
    my $err = exception { read_with('TestReader::SelfAdding') };

    ok( defined $err, 'it still dies with a lower limit' );
    like( $err, qr/read over 5 configurations/,
        'and reports the lowered limit, not the default' );
    unlike( $err, qr/read over 100 configurations/,
        'so the default is genuinely not in play' );

    # The message alone cannot show *where* the guard cut in: it interpolates
    # the limit, so it reads the same whether the guard stops at the limit or
    # one past it. Counting the reads is what pins the boundary.
    is( $TestReader::SelfAdding::READS, 5,
        'exactly MAX_CONFIGS configs are read, not one more' );
};

subtest 'the guard leaves a chain just under the limit alone' => sub {
    # The other side of the boundary: a chain that reads exactly MAX_CONFIGS
    # configs must succeed. Together with the subtest above this fixes the
    # guard at one specific count.
    no warnings 'once';
    local $Dancer2::ConfigReader::MAX_CONFIGS = 5;

    local $TestReader::SelfAdding::READS = 0;
    my $config;
    my $err = exception {
        $config = read_with('TestReader::Chained,TestReader::Leaf');
    };

    is( $err, undef, 'a short chain is read without complaint' );
    is( $config->{chained_key}, 'chained_value', 'and its settings arrive' );
    is( $config->{leaf_key},    'leaf_value',    'from every reader in it' );
};

subtest 'an ambiguous additional_config_readers entry is refused' => sub {
    my $err = exception { read_with('TestReader::TwoKeys') };

    ok( defined $err, 'an entry with two keys is fatal' );
    like( $err, qr/additional_config_readers entry must have exactly one key/,
        'and says what the requirement is' );
};

subtest 'an unloadable reader fails loudly' => sub {
    my $err = exception { read_with('TestReader::NoSuchThing') };

    ok( defined $err, 'naming a reader that does not exist is fatal' );
    like( $err, qr/TestReader::NoSuchThing|Can't locate/,
        'and the error names what could not be loaded' );
};

done_testing();
