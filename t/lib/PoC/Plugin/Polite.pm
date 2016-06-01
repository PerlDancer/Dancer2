package PoC::Plugin::Polite;
# ABSTRACT - register Dancer2::Plugin::Polite under a diferent namespace

use Dancer2::Plugin;

has polite => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->app->with_plugin( 'Polite' );
    },
    handles => [ qw( smiley add_smileys ) ],
);

plugin_keywords 'add_smileys';

register_plugin;
1;

