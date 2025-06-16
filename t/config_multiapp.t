use strict;
use warnings;

use Test::More;
use File::Spec;

use lib '.';
use t::app::t1::lib::App1;
use t::app::t1::lib::Sub::App2;
use t::app::t2::lib::App3;

for my $app ( @{ Dancer2->runner->apps } ) {
    # Need to determine path to config; use apps' name for now..
    my $path = $app->name eq 'App3' ? 't2' : 't1';

    is $app->config->{app}->{config}, 'ok',
        $app->name . ": config loaded properly"
}

done_testing;
