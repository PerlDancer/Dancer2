use strict;
use warnings;

use Test::More;
use File::Spec;

use t::app::t2::lib::App3;

is( App3->runner->config->{app}->{config}, 'ok', 'config loaded properly' );
is_deeply(
    App3->runner->config_files,
    [ File::Spec->rel2abs(File::Spec->catfile( 't', 'app', 't2', 'config.yml' )) ],
    'config files found'
);

done_testing;
