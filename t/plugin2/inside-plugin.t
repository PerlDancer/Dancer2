use strict;
use warnings;

use Test::More;

BEGIN {
    package Dancer2::Plugin::InsidePlugin;

    use Dancer2::Plugin;

    has inside => (
        is => 'ro',
        lazy => 1,
        default => sub {
            my $app = shift;
            return $app->plugin->config->{ja};
        },
    );
}

BEGIN {
    package Dancer2::Plugin::TestPlugin;

    use Dancer2::Plugin;

    has inside_plugin => (
        is => 'ro',
        default => sub {
            scalar $_[0]->app->with_plugin( 'InsidePlugin' )
        },
        handles => [ 'inside' ],
    );

    sub BUILD {
        my $plugin = shift;
        $plugin->config;
    };
}

{
    package MyApp;

    use Dancer2;

    use Dancer2::Plugin::TestPlugin;

    set plugins => {
        InsidePlugin => {
            'ja' => 'da',
        },
        TestPlugin => {
            'nein' => 'ne',
        }
    };
}

# check whether both plugins are registered
my $app = MyApp::app();
my $plugins = $app->plugins;
my $plugin_ct = scalar(@$plugins);

ok ($plugin_ct == 2, 'Test number of plugins.')
    || diag "Found $plugin_ct plugins instead of 2.";

my $test_plugin = $app->with_plugin('TestPlugin');
my $inside_plugin = $test_plugin->inside_plugin;

isa_ok( $test_plugin, 'Dancer2::Plugin::TestPlugin' );
isa_ok( $inside_plugin, 'Dancer2::Plugin::InsidePlugin' );

# test configuration values
ok ($test_plugin->config->{nein} eq 'ne', 'Test config of TestPlugin.')
    || diag "Found instead of expected 'ne': ", $test_plugin->config->{nein};

ok ($inside_plugin->config->{ja} eq 'da', 'Test config of InsidePlugin.')
    || diag "Found instead of expected 'da': ", $inside_plugin->config->{ja};

done_testing;
