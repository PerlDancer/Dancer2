package Dancer::Plugin::Foo;
use strict;
use warnings;

use Dancer;
use Dancer::Plugin;

register foo => sub {
    get '/foo' => sub {
        "/foo";
    };
};

get '/foo_sttings' => sub {
    to_yaml(plugin_settings);
};

register_plugin;
1;
