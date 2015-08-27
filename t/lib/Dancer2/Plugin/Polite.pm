package Dancer2::Plugin::Polite;

use strict;
use warnings;

use Moo;
extends 'Dancer2::Plugin2';

has smiley => (
    is => 'ro',
    default => sub {
        $_[0]->config->{smiley} || ':-)'
    }
);

sub keywords { 'add_smileys' }

sub BUILD {
    my $plugin = shift;

    $plugin->app->add_hook( Dancer2::Core::Hook->new(
        name => 'after',
        code => sub { $_[0]->content( $_[0]->content . " ... please?" ) }
    ));

    $plugin->app->add_route(
        method => 'get',
        regexp => '/goodbye',
        code   => sub { 'farewell!' },
    );

}

sub add_smileys {
    my( $plugin, $text ) = @_;

    $text =~ s/ (?<= \. ) / $plugin->smiley /xeg;

    return $text;
}

1;



