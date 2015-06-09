# ABSTRACT: Role for handling headers

package Dancer2::Core::Role::Headers;
$Dancer2::Core::Role::Headers::VERSION = '0.159002';
use Moo::Role;
use Dancer2::Core::Types;
use HTTP::Headers;

has headers => (
    is     => 'rw',
    isa    => InstanceOf ['HTTP::Headers'],
    lazy   => 1,
    coerce => sub {
        my ($value) = @_;
        return $value if ref($value) eq 'HTTP::Headers';
        HTTP::Headers->new( @{$value} );
    },
    default => sub {
        HTTP::Headers->new();
    },
    handles => [qw<header push_header>],
);

sub headers_to_array {
    my $self = shift;

    my $headers = [
        map {
            my $k = $_;
            map {
                my $v = $_;
                $v =~ s/^(.+)\r?\n(.*)$/$1\r\n $2/;
                ( $k => $v )
            } $self->headers->header($_);
          } $self->headers->header_field_names
    ];

    return $headers;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core::Role::Headers - Role for handling headers

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

When a class consumes this role, it gets a C<headers> attribute and all the
helper methods to manipulate it.

This logic is contained in this role in order to reuse the code between
L<Dancer2::Core::Response> and L<Dancer2::Core::Request> objects.

=head1 ATTRIBUTES

=head2 headers

The attribute that store the headers in a L<HTTP::Headers> object.

That attribute coerces from ArrayRef and defaults to an empty L<HTTP::Headers>
instance.

=head1 METHODS

=head2 header($name)

Return the value of the given header, if present. If the header has multiple
values, returns the list of values if called in list context, the first one
if in scalar context.

=head2 push_header

Add the header no matter if it already exists or not.

    $self->push_header( 'X-Wing' => '1' );

It can also be called with multiple values to add many times the same header
with different values:

    $self->push_header( 'X-Wing' => 1, 2, 3 );

=head2 headers_to_array

Convert the C<headers> attribute to an ArrayRef.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
