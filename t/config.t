use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Carp 'croak';

# use Dancer2::Core::Runner;
use Path::Tiny qw< path >;
use Dancer2::ConfigReader;

# undefine ENV vars used as defaults for app environment in these tests
local $ENV{DANCER_ENVIRONMENT};
local $ENV{PLACK_ENV};

# my $runner = Dancer2::Core::Runner->new();
my $location  = path( __FILE__ )->parent->child('config')->stringify;
my $location2 = path( __FILE__ )->parent->child('config2')->stringify;

{ 
    my $cfgr = Dancer2::ConfigReader->new(
        environment    => 'my_env',
        location       => $location,
        default_config => {
            content_type => 'text/html',
            charset      => 'UTF-8',
        },
    );
    is( $cfgr->config->{'application'}->{'some_feature'}, 'foo', 'Ok config' );
    is( $cfgr->config->{'charset'}, 'utf-8', 'Ok default config' );
}

{ 
    # note "bad YAML file: environments/failure.yml";
    like(
        exception {
            Dancer2::ConfigReader->new(
                environment    => 'failure',
                location       => $location,
                default_config => { },
            )->config;
        },
        qr{Unable to parse the configuration file}, 'Configuration file parsing failure',
    );
}

{
    my $cfgr = Dancer2::ConfigReader->new(
        environment    => 'any_env',
        location       => $location,
        default_config => { },
    );
    my $cfg = $cfgr->config;
    isnt( $cfg, undef, 'OK config read' );
}
{
    my $cfgr = Dancer2::ConfigReader->new(
        environment    => 'merging',
        location       => $location,
        default_config => { },
    );
    # note "config merging";
    # Check the 'application' top-level key; its the only key that
    # is currently a HoH in the test configurations
    is_deeply $cfgr->config->{application},
        {
            some_feature    => 'bar',
            another_setting => 'baz',
        },
        "full merging of configuration hashes";
}
{
    my $cfgr = Dancer2::ConfigReader->new(
        environment    => 'lconfig',
        location       => $location2,
        default_config => { },
    );
    is_deeply $cfgr->config->{application},
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

done_testing;
