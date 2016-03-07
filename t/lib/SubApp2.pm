package t::lib::SubApp2;
use strict;
use warnings;

use Dancer2;
use lib 't/lib';
use Dancer2::Plugin::DancerPlugin;
install_hooks;

get '/subapp2' => sub {
    2;
};

1;
