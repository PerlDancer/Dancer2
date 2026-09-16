use strict;
use warnings;

use Test::More;
use Path::Tiny ();

use Dancer2::ConfigReader;

# How the config files combine. Dancer2 reads, in order:
#
#   <location>/config.yml
#   <location>/config_local.yml
#   <location>/environments/<environment>.yml
#   <location>/environments/<environment>_local.yml
#
# and merges each over the last with Hash::Merge::Simple, which merges *into*
# nested hashes rather than replacing them. That distinction is the point of
# this file: an environment file that sets one key inside engines.session.Simple
# must not wipe out the sibling keys the base config set there.

my $DIR;
BEGIN {
    $DIR = Path::Tiny->tempdir;
    $DIR->child('environments')->mkpath;

    $DIR->child('config.yml')->spew_utf8( <<'YML' );
appname: BaseApp
layout: base_layout
base_only: base_value
strict_config: 0
engines:
  session:
    Simple:
      cookie_name: base.sid
      cookie_path: /base
      is_secure: 0
  template:
    TemplateToolkit:
      start_tag: '[%'
YML

    $DIR->child('config_local.yml')->spew_utf8( <<'YML' );
layout: local_layout
local_only: local_value
YML

    $DIR->child( 'environments', 'production.yml' )->spew_utf8( <<'YML' );
layout: prod_layout
prod_only: prod_value
engines:
  session:
    Simple:
      cookie_name: prod.sid
YML

    $DIR->child( 'environments', 'development.yml' )->spew_utf8( <<'YML' );
layout: dev_layout
YML
}

# DANCER_CONFDIR would override the location we pass in, so make sure a value
# inherited from the surrounding environment cannot reach these tests.
sub read_config_for {
    my $environment = shift;
    local $ENV{DANCER_CONFDIR};
    delete local $ENV{DANCER_CONFDIR};
    local $ENV{DANCER_ENVDIR};
    delete local $ENV{DANCER_ENVDIR};

    return Dancer2::ConfigReader->new(
        location       => $DIR->stringify,
        environment    => $environment,
        default_config => {},
    )->config;
}

subtest 'each file layer overrides the one before it' => sub {
    my $config = read_config_for('production');

    # The environment file is read last, so it wins outright.
    is( $config->{layout}, 'prod_layout',
        'the environment file beats config_local and config' );

    # Keys only one layer sets all survive.
    is( $config->{appname},    'BaseApp',     'a base-only key survives' );
    is( $config->{base_only},  'base_value',  'and so does another' );
    is( $config->{local_only}, 'local_value', 'a config_local-only key survives' );
    is( $config->{prod_only},  'prod_value',  'an environment-only key survives' );
};

subtest 'a different environment picks up a different file' => sub {
    my $config = read_config_for('development');

    is( $config->{layout}, 'dev_layout',
        'the development environment file is used instead' );

    # config_local still applies - it is not environment-specific.
    is( $config->{local_only}, 'local_value',
        'config_local applies regardless of environment' );
    is( $config->{base_only}, 'base_value', 'and so does the base config' );

    # production.yml must not have leaked in.
    is( $config->{prod_only}, undef,
        'the production environment file is not read' );
};

subtest 'an environment file merges into a nested block, not over it' => sub {
    my $config = read_config_for('production');

    my $simple = $config->{engines}{session}{Simple};

    # This is the assertion this file exists for. production.yml sets only
    # cookie_name inside engines.session.Simple. If the merge replaced the
    # block instead of merging into it, cookie_path and is_secure would be gone
    # and the session engine would silently fall back to its defaults.
    is( $simple->{cookie_name}, 'prod.sid',
        'the environment file overrides the key it sets' );
    is( $simple->{cookie_path}, '/base',
        'while a sibling key from the base config survives' );
    is( $simple->{is_secure}, 0,
        'including one whose value is false' );

    is_deeply(
        [ sort keys %$simple ],
        [ 'cookie_name', 'cookie_path', 'is_secure' ],
        'the block has every key from both files and nothing else',
    );

    # A sibling block the environment file never mentions is untouched.
    is_deeply(
        $config->{engines}{template},
        { TemplateToolkit => { start_tag => '[%' } },
        'an engine block the environment file does not mention is unchanged',
    );
};

subtest 'a missing config directory is not an error' => sub {
    my $empty = Path::Tiny->tempdir;

    local $ENV{DANCER_CONFDIR};
    delete local $ENV{DANCER_CONFDIR};
    local $ENV{DANCER_ENVDIR};
    delete local $ENV{DANCER_ENVDIR};

    # 'from_default' is not a key Dancer2 knows, and strict_config defaults to
    # on, so reading this warns. Captured and asserted rather than silenced,
    # because it pins something worth knowing: the strict-key check inspects
    # the whole merged config, including whatever arrived via default_config,
    # not only what was read from files.
    my @warnings;
    my $config = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        Dancer2::ConfigReader->new(
            location       => $empty->stringify,
            environment    => 'production',
            default_config => { from_default => 'default_value' },
        )->config;
    };

    is( $config->{from_default}, 'default_value',
        'the default config comes through when there are no files' );
    is( $config->{appname}, undef, 'and nothing is invented' );

    is( scalar @warnings, 1, 'exactly one warning is emitted' );
    like( $warnings[0], qr/Unknown configuration key 'from_default'/,
        'and it is the strict-key check reaching a default_config key' );
};

done_testing();
