package t::lib::SubApp2;
use strict;
use warnings;

use Dancer;
use t::lib::Dancer1Plugin;
install_hooks;

get '/subapp2' => sub {
    2;
};

1;

