package Dancer::Core::Role::Engine;
use Moo::Role;
use Dancer::Moo::Types;

with 'Dancer::Core::Role::Hookable';

requires 'type';

has context => (
    is => 'rw',
    isa => sub { ObjectOf('Dancer::Core::Context', @_) },
);

has config => (
    is => 'rw',
    isa  => sub { HashRef(@_) },
    default => sub  { {} },
);

1;
