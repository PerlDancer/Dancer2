package t::lib::App1;
use strict;
use warnings;

use Dancer;
use t::lib::Dancer1Plugin;

install_hooks;

get '/app1' => sub {
    session 'before_plugin';
};

1;

