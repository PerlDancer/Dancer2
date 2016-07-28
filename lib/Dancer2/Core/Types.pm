package Dancer2::Core::Types;
# ABSTRACT: Moo types for Dancer2 core.

use strict;
use warnings;
use Scalar::Util 'blessed', 'looks_like_number';
use MooX::Types::MooseLike 0.16 'exception_message';
use MooX::Types::MooseLike::Base qw/:all/;

use Exporter 'import';
our @EXPORT;
our @EXPORT_OK;

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

my $definitions = [
    {   name => 'ReadableFilePath',
        test => sub { -e $_[0] && -r $_[0] },
        message =>
          sub { return exception_message( $_[0], 'ReadableFilePath' ) },
        inflate => 0,
    },
    {   name => 'WritableFilePath',
        test => sub { -e $_[0] && -w $_[0] },
        message =>
          sub { return exception_message( $_[0], 'WritableFilePath' ) },
        inflate => 0,
    },

    # Dancer2-specific types
    {   name       => 'Dancer2Prefix',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {

            # a prefix must start with the char '/'
            # index is much faster than =~ /^\//
            index( $_[0], '/' ) == 0;
        },
        message =>
          sub { return exception_message( $_[0], 'a Dancer2Prefix' ) },
        inflate => 0,
    },
    {   name       => 'Dancer2AppName',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {

            # TODO need a real check of valid app names
            $_[0] =~ $namespace;
        },
        message => sub {
            return exception_message(
                ($_[0] && length( $_[0] )) ? $_[0] : 'Empty string',
                'a Dancer2AppName'
            );
        },
        inflate => 0,
    },
    {   name       => 'Dancer2Method',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {
            grep {/^$_[0]$/} map +( lc ), keys %supported_http_methods
        },
        message =>
          sub { return exception_message( $_[0], 'a Dancer2Method' ) },
        inflate => 0,
    },
    {   name       => 'Dancer2HTTPMethod',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {
            grep {/^$_[0]$/} keys %supported_http_methods
        },
        message =>
          sub { return exception_message( $_[0], 'a Dancer2HTTPMethod' ) },
        inflate => 0,
    },
];

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
    push @$definitions, {
        name => $type,
        test => sub {
            return
                 $_[0]
              && blessed( $_[0] )
              && ref( $_[0] ) eq 'Dancer2::Core::' . $type;
        },
        inflate => 0,
    };
}

MooX::Types::MooseLike::register_types( $definitions, __PACKAGE__ );

# Export everything by default.
@EXPORT = ( @MooX::Types::MooseLike::Base::EXPORT_OK, @EXPORT_OK );

1;

__END__

=head1 DESCRIPTION

Type definitions for Moo attributes. These are defined as subroutines.

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

L<MooX::Types::MooseLike> for more available types

=cut
