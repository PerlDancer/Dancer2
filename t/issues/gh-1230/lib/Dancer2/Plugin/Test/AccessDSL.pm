package Dancer2::Plugin::Test::AccessDSL;
use strict;
use warnings;
use Dancer2::Plugin;

plugin_keywords('change_response_status');

sub change_response_status {
    my $self   = shift;
    my $caller = caller(1);

    ::is( $self->app->name, 'OtherApp', 'Appname is OtherApp' );

    ::is(
        $caller,
        'Dancer2::Plugin::Test::AccessPluginDSL',
        'The caller class is the first plugin (AccessPluginDSL)',
    );

    ::ok(
        ::exception(sub{ $self->app->dsl }),
        'Cannot call DSL via app (bc appname is app)',
    );

    ::ok(
        ::exception( sub { $self->app->name->dsl } ),
        'Cannot call DSL via appname (bc it is not the consumer class)',
    );

    ::ok(
        ::exception( sub { OtherApp->status(400) } ),
        'Cannot call DSL via appname string (bc it is not the consumer class)',
    );

    ::is(
        ::exception( sub { App::Extra::status(400) } ),
        undef,
        'Was able to successfully call the DSL (via consumer class)',
    );

    ::is(
        $self->app->response->status(),
        400,
        'Status was set correctly',
    );

    ::is(
        ::exception( sub { $self->dsl->status(200) } ),
        undef,
        'Was able to successfully call the DSL (via plugin->dsl)',
    );

    ::is(
        $self->app->response->status(),
        200,
        'Status was set correctly',
    );
}

1;
