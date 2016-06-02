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

register_hook 'smileys';

plugin_keywords qw(add_smileys hooked_smileys);

sub hooked_smileys {
    my ($self, @args) = @_;
    $self->execute_plugin_hook('smileys');
    $self->add_smileys(@args);
};

register_plugin;
1;

