use strict;
use warnings;
package TestPlugin;
use Dancer2::Plugin;

sub test {
    my ($self) = @_;
    $self->app->cookie($self->app->name => 'foo', http_only => 0);
    return ( $self->app->name, $self->dsl->app->name );
};

plugin_keywords 'test';

1;
