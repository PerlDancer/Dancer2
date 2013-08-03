use strict;
use warnings;

use Test::More;

# The order is important!
Dancer2::ModuleLoader->require('Path::Class')
  or plan skip_all => 'Path::Class not present';

use t::app::t1::lib::App1;

is( App1->runner->config->{app}->{config}, 'ok', 'config loaded properly' );
is_deeply(
    App1->runner->config_files,
    [ Path::Class::file( 't', 'app', 't1', 'config.yml' )->absolute ],
    'config files found'
);

done_testing;

