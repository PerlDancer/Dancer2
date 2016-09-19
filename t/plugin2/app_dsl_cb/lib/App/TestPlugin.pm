package App::TestPlugin;
use strict;
use warnings;
use Dancer2::Plugin;

plugin_keywords('foo_from_plugin');

sub foo_from_plugin {
    my ( $self, $arg ) = @_;
    ::is( $arg, 'Foo', 'Correct argument to plugin' );
    params();
    return 'OK';
}

register_plugin();

1;
