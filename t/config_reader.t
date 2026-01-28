use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Carp 'croak';

use Path::Tiny qw< path >;
use Dancer2::Core::Runner;
use Dancer2::ConfigReader;
use Dancer2::ConfigReader::Config::Any;

# undefine ENV vars used as defaults for app environment in these tests
local $ENV{DANCER_ENVIRONMENT};
local $ENV{PLACK_ENV};

my $runner = Dancer2::Core::Runner->new();
my $location = path( __FILE__() )->sibling('config');
my $location2 = path( __FILE__() )->sibling('config2');

{

    package ConfigUser;
    use Moo;
    with 'Dancer2::Core::Role::HasConfig';

    has environment    => ( is => 'ro', required => 1 );
    has location       => ( is => 'ro', required => 1 );
    has default_config => ( is => 'ro', required => 1 );

    sub _build_config {
        my $self = shift;
        return Dancer2::ConfigReader->new(
            environment    => $self->environment,
            location       => $self->location,
            default_config => $self->default_config,
        )->config;
    }
}

sub config_any {
    my ( $environment, $location ) = @_;
    return Dancer2::ConfigReader::Config::Any->new(
        environment => $environment,
        location    => $location,
    );
}

sub config_reader {
    my ( $environment, $location ) = @_;
    return Dancer2::ConfigReader->new(
        environment    => $environment,
        location       => $location,
        default_config => $runner->config,
    );
}

sub config_user {
    my ( $environment, $location ) = @_;
    return ConfigUser->new(
        environment    => $environment,
        location       => $location,
        default_config => $runner->config,
    );
}

my $d = config_any( 'development', $location );
is_deeply $d->config_files,
  [ path( $location, 'config.yml' ), ],
  "config_files() only sees existing files";

my $f_any = config_any( 'production', $location );
is $f_any->does('Dancer2::Core::Role::ConfigReader'), 1,
  "role Dancer2::Core::Role::ConfigReader is consumed";

is_deeply $f_any->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'production.yml' ),
  ],
  "config_files() works";

my $j = config_any( 'staging', $location );
is_deeply $j->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'staging.json' ),
  ],
  "config_files() does JSON too!";

note "bad YAML file";
my $fail_any = config_any( 'failure', $location );
is $fail_any->environment, 'failure';

is_deeply $fail_any->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'failure.yml' ),
  ],
  "config_files() works";

like(
    exception { config_reader( 'failure', $location->stringify )->config },
    qr{Unable to parse the configuration file}, 'Configuration file parsing failure',
);

note "config merging";
my $m = config_reader( 'merging', $location->stringify );

# Check the 'application' top-level key; its the only key that
# is currently a HoH in the test configurations
is_deeply $m->config->{application},
  { some_feature    => 'bar',
    another_setting => 'baz',
  },
  "full merging of configuration hashes";

{
    my $l_any = config_any( 'lconfig', $location2->stringify );

    is_deeply $l_any->config_files,
      [ path( $location2, 'config.yml' ),
        path( $location2, 'config_local.yml' ),
        path( $location2, 'environments', 'lconfig.yml' ),
        path( $location2, 'environments', 'lconfig_local.yml' ),
      ],
      "config_files() with local config works";

    my $l = config_reader( 'lconfig', $location2->stringify );
    is_deeply $l->config->{application},
      { feature_1 => 'foo',
        feature_2 => 'alpha',
        feature_3 => 'replacement',
        feature_4 => 'blat',
        feature_5 => 'beta',
        feature_6 => 'bar',
        feature_7 => 'baz',
        feature_8 => 'goober',
      },
      "full merging of local configuration hashes";

}

note "config parsing";

my $f = config_user( 'production', $location->stringify );
is $f->config->{main},        1;
is $f->config->{charset},     'utf-8', "normalized UTF-8 to utf-8";

ok( $f->has_setting('charset') );
ok( !$f->has_setting('foobarbaz') );

note "default values";
is $f->setting('apphandler'),   'Standalone';

like(
    exception {
        config_reader( 'production', $location->stringify )
          ->_normalize_config( { charset => 'BOGUS' } );
    },
    qr{Charset defined in configuration is wrong : couldn't identify 'BOGUS'},
    'Configuration file charset failure',
);

{

    package Foo;
    use Carp 'croak';
    sub foo { croak "foo" }
}

is $f->setting('traces'), 0;
unlike( exception { Foo->foo() }, qr{Foo::foo}, "traces are not enabled", );

$f->setting( traces => 1 );
like( exception { Foo->foo() }, qr{Foo::foo}, "traces are enabled", );

{
    my $tmpdir = Path::Tiny->tempdir( CLEANUP => 1, TMPDIR => 1 );
    $ENV{DANCER_CONFDIR} = $tmpdir;
    my $f = config_any( 'production', $location->stringify );
    is $f->config_location, $tmpdir;
}

done_testing;
