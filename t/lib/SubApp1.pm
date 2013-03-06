package t::lib::SubApp1;
use strict;
use warnings;

use Dancer2;
use t::lib::DancerPlugin;
install_hooks;

get '/subapp1' => sub {
    1;
};

1;

