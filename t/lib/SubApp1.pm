package t::lib::SubApp1;
use strict;
use warnings;

use Dancer2;
use lib 't/lib';
use Dancer2::Plugin::DancerPlugin;
install_hooks;

get '/subapp1' => sub {
    1;
};

1;
