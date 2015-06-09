package Dancer2::Core::Role::Response;
# ABSTRACT: A role defining respones
$Dancer2::Core::Role::Response::VERSION = '0.159002';
use Moo::Role;

requires 'to_psgi';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core::Role::Response - A role defining respones

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This role defines how a L<Dancer2> response should behave. Currently it only
supports a single check: C<to_psgi>.

A Dancer2 response object must provide the C<to_psgi> method.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
