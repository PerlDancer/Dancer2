# ABSTRACT: Role for handling headers

package Dancer2::Core::Role::Headers;

use Moo::Role;
use Dancer2::Core::Types;
use HTTP::Headers::Fast;

has headers => (
    is     => 'rw',
    isa    => InstanceOf ['HTTP::Headers::Fast'],
    lazy   => 1,
    coerce => sub {
        my ($value) = @_;
        return $value if ref($value) eq 'HTTP::Headers::Fast';
        HTTP::Headers::Fast->new( @{$value} );
    },
    default => sub {
        HTTP::Headers::Fast->new();
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

=head1 DESCRIPTION

When a class consumes this role, it gets a C<headers> attribute and all the
helper methods to manipulate it.

This logic is contained in this role in order to reuse the code between
L<Dancer2::Core::Response> and L<Dancer2::Core::Request> objects.

=attr headers

The attribute that store the headers in a L<HTTP::Headers::Fast> object.

That attribute coerces from ArrayRef and defaults to an empty L<HTTP::Headers::Fast>
instance.

=method header($name)

Return the value of the given header, if present. If the header has multiple
values, returns the list of values if called in list context, the first one
if in scalar context.

=method push_header

Add the header no matter if it already exists or not.

    $self->push_header( 'X-Wing' => '1' );

It can also be called with multiple values to add many times the same header
with different values:

    $self->push_header( 'X-Wing' => 1, 2, 3 );

=method headers_to_array

Convert the C<headers> attribute to an ArrayRef.

=cut
