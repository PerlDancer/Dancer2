use strict;
use warnings;

use Test::More;
use File::Spec;

BEGIN {
    # undefine ENV vars used as defaults for app environment in these tests
    local $ENV{DANCER_ENVIRONMENT};
    local $ENV{PLACK_ENV};
    $ENV{DANCER_CONFDIR} = './t/app/t1';
}
use lib '.';
use lib './t/lib';

use Dancer2::Core::App;

subtest basic => sub {
    $ENV{DANCER_CONFIG_READERS}
        = 'Dancer2::ConfigReader::Config::Any,Dancer2::ConfigReader::TestDummy';
    my $app = Dancer2::Core::App->new( name => 'basic' );

    is $app->config->{app}->{config}, 'ok',
        $app->name . ": config loaded properly";
    is $app->config->{dummy}->{dummy_subitem}, 2,
        $app->name . ": dummy config loaded properly";
};

subtest additional_config_readers => sub {
    $ENV{DANCER_CONFIG_READERS} = 'Dancer2::ConfigReader::Additional';

    my $app = Dancer2::Core::App->new( name => 'additional' );

    is $app->config->{app}->{config}, 'ok',
        $app->name . ": config loaded properly";
    is $app->config->{dummy}->{dummy_subitem}, 2,
        $app->name . ": dummy config loaded properly";
};

done_testing;
