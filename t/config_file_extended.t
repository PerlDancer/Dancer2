use strict;
use warnings;

use Test::More;
use File::Spec;

BEGIN {
    # undefine ENV vars used as defaults for app environment in these tests
    local $ENV{DANCER_ENVIRONMENT};
    local $ENV{PLACK_ENV};
    $ENV{DANCER_CONFIG_READERS} = 'Dancer2::ConfigReader::File::Extended';
    $ENV{DANCER_FILE_EXTENDED_ONE} = 'Extended String';
    $ENV{DANCER_FILE_EXTENDED_TWO} = 'ExtendedToo';
}
use lib '.';
use lib './t/lib';

use t::app::t_config_file_extended::lib::App1;

my $app = Dancer2->runner->apps->[0];

is_deeply $app->config_files,
    [ File::Spec->rel2abs(File::Spec->catfile( 't', 'app',
                't_config_file_extended', 'config.yml' )) ],
    $app->name . ": config files found";

is $app->config->{app}->{config}, 'ok',
    $app->name . ": config loaded properly";
is $app->config->{extended}->{one}, 'Extended String',
    $app->name . ": extended config (extended:one) loaded properly";
is $app->config->{extended}->{two}, 'Begin ExtendedToo End',
    $app->name . ": extended config (extended:two) loaded properly";

done_testing;
