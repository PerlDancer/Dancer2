package Dancer2::Plugin::Test::AccessPluginDSL;
use strict;
use warnings;
use Dancer2::Plugin;
use Dancer2::Plugin::Test::AccessDSL;

plugin_keywords('test_change_response_status');

sub test_change_response_status {
    my $self   = shift;
    my $caller = caller(1);
    ::is( $self->app->name, 'OtherApp', 'Appname is OtherApp' );
    ::is( $caller, 'App::Extra', 'The caller class is App::Extra' );

    ::ok(
        ::exception( sub { App::Extra::change_response_status() } ),
        'App does not receive DSL from our inner Plugin',
    );

    ::is(
        ::exception( sub { change_response_status() } ),
        undef,
        'Successfully called the plugin DSL (via plugin->dsl)',
    );

    ::is(
        $self->app->response->status(),
        200,
        'Status was set correctly',
    );
}

1;
