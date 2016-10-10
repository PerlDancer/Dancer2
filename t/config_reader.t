use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Carp 'croak';

use Dancer2::Core::Runner;
use Dancer2::FileUtils qw/dirname path/;
use File::Spec;
use File::Temp;

my $runner = Dancer2::Core::Runner->new();
my $location = File::Spec->rel2abs( path( dirname(__FILE__), 'config' ) );
my $location2 = File::Spec->rel2abs( path( dirname(__FILE__), 'config2' ) );

{

    package Prod;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub name {'Prod'}

    sub _build_environment    {'production'}
    sub _build_location       {$location}
    sub _build_default_config {$runner->config}

    package Dev;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub _build_environment    {'development'}
    sub _build_location       {$location};
    sub _build_default_config {$runner->config}

    package Failure;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub _build_environment    {'failure'}
    sub _build_location       {$location}
    sub _build_default_config {$runner->config}

    package Staging;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub _build_environment    {'staging'}
    sub _build_location       {$location}
    sub _build_default_config {$runner->config}

    package Merging;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub name {'Merging'}

    sub _build_environment    {'merging'}
    sub _build_location       {$location}
    sub _build_default_config {$runner->config}

    package LocalConfig;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    sub name {'LocalConfig'}

    sub _build_environment    {'lconfig'}
    sub _build_location       {$location2}
    sub _build_default_config {$runner->config}

}

my $d = Dev->new();
is_deeply $d->config_files,
  [ path( $location, 'config.yml' ), ],
  "config_files() only sees existing files";

my $f = Prod->new;
is $f->does('Dancer2::Core::Role::ConfigReader'), 1,
  "role Dancer2::Core::Role::ConfigReader is consumed";

is_deeply $f->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'production.yml' ),
  ],
  "config_files() works";

my $j = Staging->new;
is_deeply $j->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'staging.json' ),
  ],
  "config_files() does JSON too!";

note "bad YAML file";
my $fail = Failure->new;
is $fail->environment, 'failure';

is_deeply $fail->config_files,
  [ path( $location, 'config.yml' ),
    path( $location, 'environments', 'failure.yml' ),
  ],
  "config_files() works";

like(
    exception { $fail->config },
    qr{Unable to parse the configuration file}, 'Configuration file parsing failure',
);

note "config merging";
my $m = Merging->new;

# Check the 'application' top-level key; its the only key that
# is currently a HoH in the test configurations
is_deeply $m->config->{application},
  { some_feature    => 'bar',
    another_setting => 'baz',
  },
  "full merging of configuration hashes";

{
    my $l = LocalConfig->new;

    is_deeply $l->config_files,
      [ path( $location2, 'config.yml' ),
        path( $location2, 'config_local.yml' ),
        path( $location2, 'environments', 'lconfig.yml' ),
        path( $location2, 'environments', 'lconfig_local.yml' ),
      ],
      "config_files() with local config works";

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

is $f->config->{show_errors}, 0;
is $f->config->{main},        1;
is $f->config->{charset},     'utf-8', "normalized UTF-8 to utf-8";

ok( $f->has_setting('charset') );
ok( !$f->has_setting('foobarbaz') );

note "default values";
is $f->setting('apphandler'),   'Standalone';

like(
    exception { $f->_normalize_config( { charset => 'BOGUS' } ) },
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
    my $tmpdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );
    $ENV{DANCER_CONFDIR} = $tmpdir;
    my $f = Prod->new;
    is $f->config_location, $tmpdir;
}

done_testing;
