package t::lib::Dancer1Plugin;
use strict;
use warnings;

use Dancer::Plugin;
my $counter = 0;

register around_get => sub {
    get '/foo/plugin' => sub {
        'foo plugin';
    };
};

register install_hooks => sub {
    hook 'before' => sub {
        session before_plugin => ++$counter;
    };
};

register_plugin for_versions => [2];

1;

