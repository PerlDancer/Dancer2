# ABSTRACT: TODO

package Dancer::Core::Types;

use strict;
use warnings;
use Scalar::Util 'blessed', 'looks_like_number';
use MooX::Types::MooseLike 0.16;
use MooX::Types::MooseLike::Base qw/:all/;
use MooX::Types::MooseLike::Numeric qw/:all/;

use Exporter 'import';
our @EXPORT;
our @EXPORT_OK;

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
    {
        name => 'ReadableFilePath',
        test => sub { -e $_[0] && -r $_[0] },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `ReadableFilePath'" }
    },
    {
        name => 'WritableFilePath',
        test => sub { -e $_[0] && -w $_[0] },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `WritableFilePath'" }
    },
    # Dancer-specific types
    {
        name => 'DancerPrefix',
        test => sub {
            return 1 if !defined $_[0];
            # a prefix must start with the char '/'
            # index is much faster than =~ /^\//
            ref(\$_[0]) eq 'SCALAR' && (index($_[0], '/') == 0);
        },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `DancerPrefix'" }
    },
    {
        name => 'DancerAppName',
        test => sub {
            # TODO need a real check of valid app names
            return 1 if !defined $_[0];
            ref(\$_[0]) eq 'SCALAR' && $_[0] =~ $namespace
        },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `DancerAppName'" }
    },
    {
        name => 'DancerMethod',
        test => sub {
            return 1 if !defined $_[0];
            grep { /^$_[0]$/ } qw(get head post put delete options patch)
        },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `DancerMethod'" }
    },
    {
        name => 'DancerHTTPMethod',
        test => sub {
            return 1 if !defined $_[0];
            grep { /^$_[0]$/ } qw(GET HEAD POST PUT DELETE OPTIONS PATCH)
        },
        message => sub { "The value `$_[0]' does not pass the type constraint for type `DancerHTTPMethod'" }
    },
];

# generate abbreviated class types for core dancer objects
for my $type (qw/App Request Response Context Runner Dispatcher MIME/) {
    push @$definitions, {
        name => $type,
        test => sub {
            return $_[0]
              && blessed( $_[0] )
              && ref( $_[0] ) eq 'Dancer::Core::' . $type;
        },
        message => sub { "The value `$_[0]' does not pass the constraint check." }
    };
}

MooX::Types::MooseLike::register_types($definitions, __PACKAGE__);

# Export everything by default.
@EXPORT = (@MooX::Types::MooseLike::Base::EXPORT_OK, @EXPORT_OK);

1;

__END__

=head1 DESCRIPTION

Type definitions for Moo attributes. These are defined as subroutines. 

=head1 SUBROUTINES

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

=head1 SEE ALSO

L<MooX::Types::MooseLike> for more available types
