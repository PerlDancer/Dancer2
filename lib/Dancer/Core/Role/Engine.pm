# ABSTRACT: TODO

package Dancer::Core::Role::Engine;
use Moo::Role;
use Dancer::Core::Types;

with 'Dancer::Core::Role::Hookable';

has environment => (is => 'ro');
has location    => (is => 'ro');

has context => (
    is        => 'rw',
    isa       => InstanceOf ['Dancer::Core::Context'],
    clearer   => 'clear_context',
    predicate => 1,
);

has config => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

1;
