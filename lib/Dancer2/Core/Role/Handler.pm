# ABSTRACT: Role for Handlers

package Dancer2::Core::Role::Handler;
use Moo::Role;
use Dancer2::Core::Types;

=head1 REQUIREMENTS

This role requires the method C<register> to be implemented.

=cut

requires 'register';

=attr app

Contain an object of class L<Dancer2::Core::App>.

=cut

has app => (
    is  => 'ro',
    isa => InstanceOf ['Dancer2::Core::App'],
);

1;
