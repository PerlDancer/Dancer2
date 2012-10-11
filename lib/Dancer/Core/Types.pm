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
        name    => 'ReadableFilePath',
        test    => sub { -e $_[0] && -r $_[0] },
        message => sub { return exception_message($_[0], 'ReadableFilePath') }
    },
    {
        name    => 'WritableFilePath',
        test    => sub { -e $_[0] && -w $_[0] },
        message => sub { return exception_message($_[0], 'WritableFilePath') }
    },
    # Dancer-specific types
    {
        name       => 'DancerPrefix',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {
            # a prefix must start with the char '/'
            # index is much faster than =~ /^\//
            index($_[0], '/') == 0;
        },
        message    => sub { return exception_message($_[0], 'DancerPrefix') }
    },
    {
        name       => 'DancerAppName',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {
            # TODO need a real check of valid app names
            $_[0] =~ $namespace;
        },
        message    => sub { return exception_message($_[0], 'DancerAppName') }
    },
    {
        name       => 'DancerMethod',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test       => sub {
            grep { /^$_[0]$/ } qw(get head post put delete options patch)
        },
        message    => sub { return exception_message($_[0], 'DancerMethod') }
    },
    {
        name       => 'DancerHTTPMethod',
        subtype_of => 'Str',
        from       => 'MooX::Types::MooseLike::Base',
        test => sub {
            grep { /^$_[0]$/ } qw(GET HEAD POST PUT DELETE OPTIONS PATCH)
        },
        message => sub { return exception_message($_[0], 'DancerHTTPMethod') }
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

sub exception_message {
    my ($attribute_value, $type) = @_;
    $attribute_value = defined $attribute_value ? $attribute_value : 'undef';
    return "The value `${attribute_value}' does not pass the type constraint for type `${type}'";
} 

1;

