use strict;
use warnings;

use Test::More;
use File::Spec;

use t::app::t1::lib::App1;
use t::app::t1::lib::Sub::App2;
use t::app::t2::lib::App3;

for my $app ( @{ Dancer2->runner->apps } ) {
    # Need to determine path to config; use apps' name for now..
    my $path = $app->name eq 'App3' ? 't2' : 't1';

    is_deeply $app->config_files,
        [ File::Spec->rel2abs(File::Spec->catfile( 't', 'app', $path, 'config.yml' )) ],
        $app->name . ": config files found";

    is $app->config->{app}->{config}, 'ok',
        $app->name . ": config loaded properly"
}

done_testing;
