# ABSTRACT: TODO

package Dancer::Moo::Types;

use strict;
use warnings;
use Carp 'croak';
use Scalar::Util 'blessed', 'looks_like_number';

use base 'Exporter';
use vars '@EXPORT';

@EXPORT = qw(
    Str Num Bool ArrayRef HashRef CodeRef Regexp ObjectOf ConsumerOf
    ReadableFilePath WritableFilePath
    DancerPrefix DancerAppName DancerMethod DancerHTTPMethod
);

# reference definitions, please see:
# Effective Perl Programming
# Chapter 6: References
# Item 59. Compare reference types to prototypes.
# 1st edition: Joseph N. Hall, Randal L. Schwartz.
# 2nd edition: Joseph N. Hall, Joshua A. McAdams, brian d. foy.
my $arrayref  = ref [];
my $hashref   = ref {};
my $coderef   = ref sub {};
my $regexpref = ref qr//;

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
        unless _is_scalar($value);
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

    raise_type_exception Bool => $value
      if !  _is_scalar($value)
         || ($value != 0 && $value != 1);
}

sub ArrayRef {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception ArrayRef => $value
      if  ! ref($value)
         || (ref($value) ne $arrayref);
}

sub HashRef {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception HashRef => $value
      if  ! ref($value)
         || (ref($value) ne $hashref);
}

sub CodeRef {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception CodeRef => $value
      if  ! ref($value)
         || (ref($value) ne $coderef);
}

sub Regexp {
    my ($value) = @_;
    return if ! defined $value;
    raise_type_exception Regexp => $value
      if  ! ref($value)
         || (ref($value) ne $regexpref);
}

sub ObjectOf {
    my ($class, $value) = @_;
    return if ! defined $value;
    raise_type_exception "ObjectOf(${class})" => $value
      if !  blessed($value)
         || (ref($value) ne $class);
}

sub ConsumerOf {
    my ($role, $value) = @_;
    return if ! defined $value;

    raise_type_exception Consumes => $value
      if ! $value->does($role);
}

sub ReadableFilePath {
    my ($value) = @_;
    raise_type_exception ReadableFilePath => $value
      if ! -e $value || ! -r $value;
}

sub WritableFilePath {
    my ($value) = @_;
    raise_type_exception WritableFilePath => $value
      if ! -e $value || ! -w $value;
}

# Dancer-specific types

sub DancerPrefix {
    my ($value) = @_;
    return if ! defined $value;

    # a prefix must start with the char '/'
    # index is much faster than =~ /^\//
    raise_type_exception DancerPrefix => $value
      if !  _is_scalar($value)
         || (index($value, '/') != 0);
}

my $single_part = qr/
    [A-Za-z]              # must start with letter
    (?: [A-Za-z0-9_]+ )? # can continue with letters, numbers or underscore
/x;

my $namespace = qr/
    ^
    $single_part                    # first part
    (?: (?: \:\: $single_part )+ )? # optional part starting with double colon
    $
/x;

sub DancerAppName {
    my ($value) = @_;
    return if ! defined $value;

    # TODO need a real check of valid app names
    raise_type_exception DancerAppName => $value
      if !  _is_scalar($value)
         || ($value !~ $namespace);
}

sub DancerMethod {
    my ($value) = @_;
    return if ! defined $value;

    raise_type_exception DancerMethod => $value
      unless grep { /^$value$/ } qw(get head post put delete options);
}

sub DancerHTTPMethod {
    my ($value) = @_;
    return if ! defined $value;

    raise_type_exception DancerMethod => $value
      unless grep { /^$value$/ } qw(GET HEAD POST PUT DELETE OPTIONS);
}

# private

sub _is_scalar {
    my ($value) = @_;
    return ! ref($value);
}

1;

