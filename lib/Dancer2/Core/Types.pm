package Dancer2::Core::Types;
# ABSTRACT: Type::Tiny types for Dancer2 core.

use strict;
use warnings;
use Type::Library -base;
use Type::Utils -all;
use Sub::Quote 'quote_sub';

BEGIN { extends "Types::Standard" };

our %supported_http_methods = map +( $_ => 1 ), qw<
    GET HEAD POST PUT DELETE OPTIONS PATCH
>;

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

declare 'ReadableFilePath', constraint => quote_sub q{ -e $_ && -r $_ };

declare 'WritableFilePath', constraint => quote_sub q{ -e $_ && -w $_ };

declare 'Dancer2Prefix', as 'Str', where {
    # a prefix must start with the char '/'
    # index is much faster than =~ /^\//
    index($_, '/') == 0
};

declare 'Dancer2AppName', as 'Str', where {
    # TODO need a real check of valid app names
    $_ =~ $namespace;
}, message {
    sprintf("%s is not a Dancer2AppName",
        ($_ && length($_)) ? $_ : 'Empty string')
};

declare 'Dancer2Method', as Enum [map +(lc), keys %supported_http_methods];

declare 'Dancer2HTTPMethod', as Enum [keys %supported_http_methods];

# generate abbreviated class types for core dancer objects
for my $type (
    qw/
    App
    Context
    Cookie
    DSL
    Dispatcher
    Error
    Hook
    MIME
    Request
    Response
    Role
    Route
    Runner
    Server
    Session
    Types
    /
  )
{
    declare $type,
    as InstanceOf[ 'Dancer2::Core::' . $type ];
}

# Export everything by default.
our @EXPORT = __PACKAGE__->type_names;

1;

__END__

=head1 DESCRIPTION

L<Type::Tiny> definitions for Moo attributes. These are defined as subroutines.

=head1 MOO TYPES

=head2 ReadableFilePath($value)

A readable file path.

=head2 WritableFilePath($value)

A writable file path.

=head2 Dancer2Prefix($value)

A proper Dancer2 prefix, which is basically a prefix that starts with a I</>
character.

=head2 Dancer2AppName($value)

A proper Dancer2 application name.

Currently this only checks for I<\w+>.

=head2 Dancer2Method($value)

An acceptable method supported by Dancer2.

Currently this includes: I<get>, I<head>, I<post>, I<put>, I<delete> and
I<options>.

=head2 Dancer2HTTPMethod($value)

An acceptable HTTP method supported by Dancer2.

Current this includes: I<GET>, I<HEAD>, I<POST>, I<PUT>, I<DELETE>
and I<OPTIONS>.

=head1 SEE ALSO

<Types::Standard> for more available types

=cut
