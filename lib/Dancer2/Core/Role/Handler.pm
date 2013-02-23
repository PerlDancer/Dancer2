# ABSTRACT: TODO

package Dancer2::Core::Role::Handler;
use Moo::Role;
use Dancer2::Core::Types;

requires 'register';

has app => (
    is  => 'ro',
    isa => InstanceOf ['Dancer2::Core::App'],
);

1;
