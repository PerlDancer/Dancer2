# ABSTRACT: TODO

package Dancer::Core::Role::Handler;
use Moo::Role;
use Dancer::Core::Types;

requires 'register';

has app => (
    is => 'ro',
    isa => InstanceOf['Dancer::Core::App'],
);

1;
