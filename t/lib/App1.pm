package t::lib::App1;
use strict;
use warnings;

use Dancer2;
use t::lib::DancerPlugin;

install_hooks;

get '/app1' => sub {
    session 'before_plugin';
};

1;

