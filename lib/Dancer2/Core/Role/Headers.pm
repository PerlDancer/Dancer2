# ABSTRACT: TODO

package Dancer2::Core::Role::Headers;

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
        HTTP::Headers->new(@{$value});
    },
    default => sub {
        HTTP::Headers->new();
    },
);

=method header($name)

Return the value of the given header, if present. If the header has multiple
values, returns an the list of values if called in list context, the first one
in scalar.
=cut

sub header {
    my $self   = shift;
    my $header = shift;

    if (@_) {
        $self->headers->header($header => @_);
    }
    else {
        return $self->headers->header($header);
    }
}

sub push_header {
    my $self   = shift;
    my $header = shift;

    if (@_) {
        foreach my $h (@_) {
            $self->headers->push_header($header => $h);
        }
    }
    else {
        return $self->headers->header($header);
    }
}

sub headers_to_array {
    my $self = shift;

    my $headers = [
        map {
            my $k = $_;
            map {
                my $v = $_;
                $v =~ s/^(.+)\r?\n(.*)$/$1\r\n $2/;
                ($k => $v)
            } $self->headers->header($_);
        } $self->headers->header_field_names
    ];

    return $headers;
}

1;
