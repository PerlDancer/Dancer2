package t::lib::SubApp1;
use strict;
use warnings;

use Dancer;
use t::lib::Dancer1Plugin;
install_hooks;

get '/subapp1' => sub {
    1;
};

1;

