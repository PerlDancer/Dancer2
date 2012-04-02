# Abstract: TODO

package Dancer::Core::Role::Handler;
use Moo::Role;
use Dancer::Moo::Types;

requires 'register';

has app => (
    is => 'ro',
    isa => sub { ObjectOf('Dancer::Core::App', @_) },
);

1;
