use strict;
use warnings;

use Test::More;
use File::Spec;

BEGIN {
    # undefine ENV vars used as defaults for app environment in these tests
    local $ENV{DANCER_ENVIRONMENT};
    local $ENV{PLACK_ENV};
    $ENV{DANCER_CONFIG_READERS}
        = 'Dancer2::ConfigReader::FileSimple Dancer2::ConfigReader::TestDummy';
}
use lib '.';
use lib './t/lib';

use t::app::t1::lib::App1;

my $app = Dancer2->runner->apps->[0];

is_deeply $app->config_files,
    [ File::Spec->rel2abs(File::Spec->catfile( 't', 'app', 't1', 'config.yml' )) ],
    $app->name . ": config files found";

is $app->config->{app}->{config}, 'ok',
    $app->name . ": config loaded properly";
is $app->config->{dummy}->{dummy_subitem}, 2,
    $app->name . ": dummy config loaded properly";

done_testing;
