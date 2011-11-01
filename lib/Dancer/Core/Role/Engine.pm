package Dancer::Core::Role::Engine;
use Moo::Role;
use Dancer::Moo::Types;

with 'Dancer::Core::Role::Hookable';

requires 'type';
requires 'supported_hooks';

has context => (
    is => 'rw',
    isa => sub { ObjectOf('Dancer::Core::Context', @_) },
);

has config => (
    is => 'rw',
    isa  => sub { HashRef(@_) },
    default => sub  { {} },
);

sub BUILD {
    my ($self) = @_;
    $self->init if $self->can('init');
}


1;
