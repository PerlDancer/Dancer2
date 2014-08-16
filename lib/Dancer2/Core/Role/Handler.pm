package Dancer2::Core::Role::Handler;
# ABSTRACT: Role for Handlers

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
    weak_ref => 1,
);

1;
