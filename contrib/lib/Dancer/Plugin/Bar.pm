package Dancer::Plugin::Bar;
use strict;
use warnings;
use Dancer::Plugin;

register bar => sub {
    get '/bar' => sub {
        "/bar";
    };
};

register wrap_request => sub {
    request;
};

#get '/foo_sttings' => sub {
#    to_yaml(plugin_settings);
#};

register_plugin for_versions => [ 2 ];
1;
