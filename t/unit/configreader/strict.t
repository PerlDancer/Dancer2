use strict;
use warnings;

use Test::More;
use Path::Tiny ();

use Dancer2::ConfigReader;

# strict_config warns about configuration keys Dancer2 does not recognise, so a
# typo in config.yml is noticed rather than silently ignored.
#
# Its scope is deliberately narrower than "everything", and the documentation
# says so (Dancer2::Manual::Config, "strict_config"): it warns about unknown
# keys "at the top level and about unknown keys in built-in engine sections
# where the options are known". The last subtest pins that boundary, because it
# is the part that looks like a gap until you read the sentence: a mistyped
# *engine name* produces no warning at all, which is what makes third-party
# engines usable.
#
# strict_config defaults to on. Every fixture that does not mean to be warned
# about therefore has to be clean.

my %DIR;

BEGIN {
    my %fixture = (
        # Two bogus top-level keys and one bogus key inside a known engine.
        bogus_keys => <<'YML',
appname: X
not_a_real_key: 1
another_bogus: 2
engines:
  session:
    Simple:
      cookie_name: ok.sid
      bogus_engine_key: 1
YML

        # One key allowed, one not.
        with_allow => <<'YML',
appname: X
strict_config_allow:
  - not_a_real_key
not_a_real_key: 1
still_bogus: 2
YML

        # Warnings switched off entirely.
        switched_off => <<'YML',
appname: X
strict_config: 0
not_a_real_key: 1
engines:
  session:
    Simple:
      bogus_engine_key: 1
YML

        # Nothing wrong at all.
        clean => <<'YML',
appname: X
layout: main
engines:
  session:
    Simple:
      cookie_name: ok.sid
YML

        # An engine name that does not exist, and an engine *type* that does
        # not exist.
        unknown_engine => <<'YML',
appname: X
engines:
  session:
    NoSuchEngine:
      whatever_key: 1
  nosuchtype:
    Foo:
      bar: 1
YML

        # An engine key listed in strict_config_allow, which documents itself
        # as covering top-level keys only.
        allow_engine_key => <<'YML',
appname: X
strict_config_allow:
  - bogus_engine_key
engines:
  session:
    Simple:
      bogus_engine_key: 1
YML
    );

    for my $name ( keys %fixture ) {
        my $dir = Path::Tiny->tempdir;
        $dir->child('config.yml')->spew_utf8( $fixture{$name} );
        $DIR{$name} = $dir;
    }
}

# Returns the warning lines emitted while reading the named fixture.
sub warnings_for {
    my $name = shift;

    local $ENV{DANCER_CONFDIR};
    delete local $ENV{DANCER_CONFDIR};
    local $ENV{DANCER_ENVDIR};
    delete local $ENV{DANCER_ENVDIR};

    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        Dancer2::ConfigReader->new(
            location       => $DIR{$name}->stringify,
            environment    => 'production',
            default_config => {},
        )->config;
    }

    # The warnings arrive as one multi-line string; split so each complaint can
    # be asserted on individually.
    return [ grep { length } map { split /\n/ } @warnings ];
}

subtest 'unknown top-level keys are warned about' => sub {
    my $warnings = warnings_for('bogus_keys');

    ok( scalar @$warnings, 'reading the config warns' );

    my $all = join "\n", @$warnings;
    like( $all, qr/Unknown configuration key 'not_a_real_key'/,
        'the first bogus key is named' );
    like( $all, qr/Unknown configuration key 'another_bogus'/,
        'and so is the second' );
    like( $all, qr/Set strict_config => 0 to silence these warnings/,
        'and the message says how to turn it off' );

    # A key that is real must not be complained about.
    unlike( $all, qr/'appname'/, 'a recognised key is not warned about' );
};

subtest 'unknown keys inside a known engine are warned about' => sub {
    my $all = join "\n", @{ warnings_for('bogus_keys') };

    like(
        $all,
        qr/Unknown configuration key 'bogus_engine_key' for engine 'session\/Simple'/,
        'the engine key is named, with the engine it belongs to',
    );
    unlike( $all, qr/'cookie_name'/,
        'a real engine key is not warned about' );
};

subtest 'strict_config_allow suppresses only the keys it lists' => sub {
    my $all = join "\n", @{ warnings_for('with_allow') };

    unlike( $all, qr/'not_a_real_key'/,
        'the allowed key produces no warning' );
    like( $all, qr/Unknown configuration key 'still_bogus'/,
        'while a key not on the list still does' );

    # strict_config_allow itself is a known key and must not warn.
    unlike( $all, qr/'strict_config_allow'/,
        'the allow list itself is not flagged' );
};

subtest 'strict_config => 0 silences everything' => sub {
    my $warnings = warnings_for('switched_off');

    is_deeply( $warnings, [],
        'neither the top-level nor the engine key is warned about' );
};

subtest 'a clean config warns about nothing' => sub {
    # Without this, every assertion above could be passing because *something*
    # always warns.
    my $warnings = warnings_for('clean');

    is_deeply( $warnings, [], 'a config with no unknown keys is silent' );
};

subtest 'an unrecognised engine name is accepted in silence' => sub {
    # Documented behavior, not an oversight: Dancer2::Manual::Config scopes
    # strict_config to "built-in engine sections where the options are known".
    # A third-party engine - Dancer2::Session::Redis, say - has options Dancer2
    # cannot know, so it is skipped rather than flagged.
    #
    # The cost is that a *mistyped* engine name is equally silent, and the
    # engine config is then quietly ignored. Pinned so that if anyone tightens
    # this, they do it deliberately.
    my $warnings = warnings_for('unknown_engine');

    is_deeply( $warnings, [],
        'neither an unknown engine name nor an unknown engine type warns' );
};

subtest 'strict_config_allow does not cover engine keys' => sub {
    # Also documented: the allow list is described as a list of *top-level*
    # keys. Listing an engine key there does not suppress the engine warning.
    my $all = join "\n", @{ warnings_for('allow_engine_key') };

    like(
        $all,
        qr/Unknown configuration key 'bogus_engine_key' for engine 'session\/Simple'/,
        'the engine key is still warned about despite being on the allow list',
    );
};

done_testing();
