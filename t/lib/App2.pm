package t::lib::App2;
use strict;
use warnings;

use Dancer;
use t::lib::Dancer1Plugin;

install_hooks;

get '/app2' => sub {
    session 'before_plugin';
};

1;

