use strict;
use warnings;

use Test::More;
use File::Spec;

use t::app::t1::lib::Sub::App2;

is( Sub::App2->runner->config->{app}->{config}, 'ok',
    'config loaded properly' );
is_deeply(
    Sub::App2->runner->config_files,
    [ File::Spec->rel2abs(File::Spec->catfile( 't', 'app', 't1', 'config.yml' )) ],
    'config files found'
);

done_testing;
