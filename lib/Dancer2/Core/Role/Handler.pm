package Dancer2::Core::Role::Handler;
# ABSTRACT: Role for Handlers

use Moo::Role;
use Dancer2::Core::Types;

requires 'register';

has app => (
    is  => 'ro',
    isa => InstanceOf ['Dancer2::Core::App'],
    weak_ref => 1,
);

1;

__END__

=head1 REQUIREMENTS

This role requires the method C<register> to be implemented.

=attr app

Contain an object of class L<Dancer2::Core::App>.

=cut
