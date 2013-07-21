use strict;
use warnings;

use Test::More;
use Path::Class;
use t::app::t2::lib::App3;

is( App3->runner->config->{app}->{config}, 'ok', 'config loaded properly' );
is_deeply(
    App3->runner->config_files,
    [ file( 't', 'app', 't2', 'config.yml' )->absolute ],
    'config files found'
);

done_testing;

