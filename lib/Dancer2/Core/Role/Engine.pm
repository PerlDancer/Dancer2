# ABSTRACT: TODO

package Dancer2::Core::Role::Engine;
use Moo::Role;
use Dancer2::Core::Types;

with 'Dancer2::Core::Role::Hookable';

has type => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

has environment => (is => 'ro');
has location    => (is => 'ro');

has context => (
    is        => 'rw',
    isa       => InstanceOf ['Dancer2::Core::Context'],
    clearer   => 'clear_context',
    predicate => 1,
);

has config => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

requires '_build_type';

1;
