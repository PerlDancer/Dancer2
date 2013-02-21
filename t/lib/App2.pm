package t::lib::App2;
use strict;
use warnings;

use Dancer2;
use t::lib::DancerPlugin;

install_hooks;

get '/app2' => sub {
    session 'before_plugin';
};

1;

