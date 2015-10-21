package Dancer2::CLI::Command::init_plugin;
# ABSTRACT: initiate a new plugin

use strict;
use warnings;
use App::Cmd::Setup -command;
use Class::Load 'load_class';

sub description { 'Initialize a new plugin' }

sub command_names {
    qw/plugin_init/;
}

sub execute {
    my ( $self, $opts, $args ) = @_;
    my $plugin = shift @{$args}
        or $self->usage_error("Must provide a plugin name segment");
    my $class = "Dancer2::Plugin::$plugin";
    load_class($class);
    $class->init_plugin( @{$args} );
}

1;
