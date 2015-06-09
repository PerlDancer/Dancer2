package Dancer2::Core::Role::Engine;
# ABSTRACT: Role for engines
$Dancer2::Core::Role::Engine::VERSION = '0.159002';
use Moo::Role;
use Dancer2::Core::Types;

with 'Dancer2::Core::Role::Hookable';

has session => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Session'],
    writer    => 'set_session',
    clearer   => 'clear_session',
    predicate => 'has_session',
);

has config => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has request => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Request'],
    writer    => 'set_request',
    clearer   => 'clear_request',
    predicate => 'has_request',
);

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core::Role::Engine - Role for engines

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This role is intended to be consumed by all engine roles. It contains all the
shared logic for engines.

This role consumes the L<Dancer2::Core::Role::Hookable> role.

=head1 ATTRIBUTES

=head2 config

An HashRef that hosts the configuration bits for the engine.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
