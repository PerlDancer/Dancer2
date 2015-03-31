package Dancer2::Core::Role::Response;
# ABSTRACT: A role defining respones

use Moo::Role;

requires 'to_psgi';

1;

__END__

=head1 DESCRIPTION

This role defines how a L<Dancer2> response should behave. Currently it only
supports a single check: C<to_psgi>.

A Dancer2 response object must provide the C<to_psgi> method.
