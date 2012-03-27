package t::lib::Dancer1Plugin;
use strict;
use warnings;

use Dancer::Plugin;

register around_get => sub {
    get '/foo/plugin' => sub {
        'foo plugin';
    };
};

register_plugin for_versions => [ 2 ];

1;

