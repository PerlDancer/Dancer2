# ABSTRACT: TODO

package Dancer::Core::Role::Engine;
use Moo::Role;
use Dancer::Moo::Types;

with 'Dancer::Core::Role::Hookable';

requires 'type';

has environment => (is => 'ro');
has location => (is => 'ro');

has context => (
    is => 'rw',
    isa => sub { ObjectOf('Dancer::Core::Context', @_) },
);

has config => (
    is => 'rw',
    isa  => HashRef,
    default => sub  { {} },
);

1;
