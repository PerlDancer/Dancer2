package Dancer::Moo::Types;

use strict;
use warnings;
use Carp 'croak';
use Scalar::Util 'blessed', 'looks_like_number';

sub raise_type_exception {
    my ($type, $value) = @_;

    croak "The value `$value' does not pass the type "
        . "constraint check for type `$type'";
}

# generic pseudo types for Moo

sub Str {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception Str => $value
        unless _is_defined_scalar($value);
}

sub Num {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception Num => $value
      unless looks_like_number($value);
}

sub Bool {
    my ($value) = @_;
    return if ! defined $value;

    raise_type_exception Num => $value
      if !  _is_defined_scalar($value) 
         || ($value != 0 && $value != 1);
}

sub Regexp {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception Regexp => $value
      if  ! ref($value)
         || (ref($value) ne 'Regexp');
}

sub HashRef {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception HashRef => $value
      if  ! ref($value)
         || (ref($value) ne 'HASH');
}

sub CodeRef {
    my ($value) = @_;
    raise_type_exception CodeRef => $value
      if  ! ref($value)
         || (ref($value) ne 'CODE');
}


sub ArrayRef {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception ArrayRef => $value
      if  ! ref($value)
         || (ref($value) ne 'ARRAY');
}

sub ObjectOf {
    my ($class, $value) = @_;
    return if ! defined $value;
    raise_type_exception "ObjectOf(${class})" => $value
      if !  blessed($value) 
         || (ref($value) ne $class);
}

# Dancer-specific types

sub DancerPrefix {
    my ($value) = @_;
    return if ! defined $value;

    # a prefix must start with the char '/'
    # index is much faster than =~ /^\//
    raise_type_exception DancerPrefix => $value
      if !  _is_defined_scalar($value) 
         || (index($value, '/') != 0); 
}

sub DancerAppName {
    my ($value) = @_;
    return if ! defined $value;

    # TODO need a real check of valid app names
    raise_type_exception DancerAppName => $value
      if !  _is_defined_scalar($value)
         || ($value =~ /\s/); 
}

sub DancerMethod {
    my ($value) = @_;
    return if ! defined $value;

    raise_type_exception DancerMethod => $value
      unless grep { /^$value$/ } qw(get head post put delete options);
}

# private

sub _is_defined_scalar {
    my ($value) = @_;

    return if !defined $value;
    return if ref($value);
    return 1;
}


1;
