use strict;
use warnings;

use Test::More;
use Path::Class;
use t::app::t1::lib::Sub::App2;

is(Sub::App2->runner->config->{app}->{config}, 'ok', 'config loaded properly');
is_deeply(
    Sub::App2->runner->config_files,
    [file('t', 'app', 't1', 'config.yml')->absolute],
    'config files found'
);

done_testing;

