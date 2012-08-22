# ABSTRACT: TODO

package Dancer::Core::Role::Handler;
use Moo::Role;
use Dancer::Moo::Types;

requires 'register';

has app => (
    is => 'ro',
    isa => ObjectOf('Dancer::Core::App'),
);

1;
