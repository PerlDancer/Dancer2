package Dancer::Core::Role::Engine;
use Moo::Role;
use Dancer::Moo::Types;

requires 'type';

has config => (
    is => 'rw',
    isa  => sub { HashRef(@_) },
);

1;
