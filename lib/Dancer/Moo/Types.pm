# ABSTRACT: TODO

package Dancer::Moo::Types;

use strict;
use warnings;
use Carp 'croak';
use Scalar::Util 'blessed', 'looks_like_number';

use base 'Exporter';
use vars '@EXPORT';

@EXPORT = qw(
    Str Num HashRef ArrayRef CodeRef Regexp ObjectOf Bool ConsumerOf
    ReadableFilePath WritableFilePath 
    DancerPrefix DancerAppName DancerMethod DancerHTTPMethod
);

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

sub ConsumerOf {
    my ($role, $value) = @_;
    return if ! defined $value;

    raise_type_exception Consumes => $value
      if ! $value->does($role);
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
    return if ! defined $value;
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

sub DancerAppName {
    my ($value) = @_;
    return if ! defined $value;

    # TODO need a real check of valid app names
    raise_type_exception DancerAppName => $value
      if !  _is_scalar($value)
         || ($value !~ /\w/); 
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

__END__

=head1 DESCRIPTION

Type definitions for Moo attributes. These are defined as subroutines.

=head1 SUBROUTINES

=head2 Str($value)

A string.

=head2 Num($value)

A number, via L<Scalar::Util>'s C<looks_like_number>.

=head2 HashRef($value)

A hash reference.

=head2 ArrayRef($value)

An array reference.

=head2 CodeRef($value)

A code reference.

=head2 Regexp($value)

A regular expression reference.

=head2 ObjectOf($class, $value)

An object of a certain class. Utilizes L<Scalar::Util>'s C<blessed>.

=head2 Bool($value)

A boolean. Only accepts B<1> (for true) and B<0> (for false).

=head2 ConsumerOf($role, $value)

An object that consumes a certain role, i.e., I<does>.

=head2 ReadableFilePath($value)

A readable file path.

=head2 WritableFilePath($value)

A writable file path.

=head2 DancerPrefix($value)

A proper Dancer prefix, which is basically a prefix that starts with a I</>
character.

=head2 DancerAppName($value)

A proper Dancer application name.

Currently this only checks for I<\w+>.

=head2 DancerMethod($value)

An acceptable method supported by Dancer.

Currently this includes: I<get>, I<head>, I<post>, I<put>, I<delete> and
I<options>.

=head2 DancerHTTPMethod($value)

An acceptable HTTP method supported by Dancer.

Current this includes: I<GET>, I<HEAD>, I<POST>, I<PUT>, I<DELETE>
and I<OPTIONS>.

=head2 raise_type_exception($type, $value)

This isn't a type but rather a subroutine that raises an exception of type
check.

