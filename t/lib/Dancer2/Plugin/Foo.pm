package Dancer2::Plugin::Foo;

use strict;
use warnings;

use Dancer2::Plugin;

plugin_keywords 'truncate_txt';

has something => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->config->{one};
    },
);

has size => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->config->{size} || 99;
    },
);

has bar => (
    is => 'ro',
    lazy => 1,
    default => sub {
        scalar $_[0]->app->with_plugin( 'Bar' )
    },
    handles => { 'bar_baz' => 'baz' },
);

sub BUILD {
    my $plugin = shift;
    
    $plugin->app->add_hook( Dancer2::Core::Hook->new(
            name => 'after',
            code => sub { my $resp = shift; $resp->content( $resp->content 
                    . 'added by plugin with something:' .  $plugin->something
                    . $plugin->bar_baz
                ) }
        ));
}

sub truncate_txt {
    my( $plugin, $text ) = @_;
    return substr $text, 0, $plugin->size;
}

1;
