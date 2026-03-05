package Dancer2::Plugin::DancerPlugin;
use strict;
use warnings;

use Dancer2::Plugin;
my $counter = 0;

register around_get => sub {
    my $dsl = shift;
    $dsl->get(
        '/foo/plugin' => sub {
            'foo plugin';
        }
    );
};

register install_hooks => sub {
    my $dsl = shift;
    $dsl->app->add_hook( Dancer2::Core::Hook->new(
        name => 'before',
        code => sub {
            $dsl->session( before_plugin => ++$counter );
        }
    ));
};

register_plugin;
1;
