# ABSTRACT: Role for engines

package Dancer2::Core::Role::Engine;
use Moo::Role;
use Dancer2::Core::Types;

=head1 DESCRIPTION

This role is intended to be consumed by all engine roles. It contains all the
shared logic for engines.

This role consumes the L<Dancer2::Core::Role::Hookable> role.

=cut

with 'Dancer2::Core::Role::Hookable';

=attr environment 

The value of the current environment

=cut

has environment => ( is => 'ro' );

has location => ( is => 'ro' );

=attr context

A L<Dancer2::Core::Context> object

=cut

has context => (
    is        => 'rw',
    isa       => InstanceOf ['Dancer2::Core::Context'],
    clearer   => 'clear_context',
    predicate => 1,
);

=attr config

An HashRef that hosts the configuration bits for the engine.

=cut

has config => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

1;
