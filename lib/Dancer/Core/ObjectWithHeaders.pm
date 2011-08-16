package Dancer::Core::ObjectWithHeaders;

# since both Dancer::Core::Request and Dancer::Core::Response have headers to
# deal with (and in exactly the same manner), I've refactored all the headers
# bits in this class.
# A role would even be better, but as far as I can understand, I cant use 'has'
# with Role::Tiny.
# Since we wont have multiple inheritance, I suppose that's not an issue
# there...

use Moo;
use Dancer::Moo::Types;
use HTTP::Headers;

has headers => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('HTTP::Headers' => @_) },
    coerce => sub { 
        my ($value) = @_;
        return $value if ref($value) eq 'HTTP::Headers';
        HTTP::Headers->new(@{ $value });
    },
);

sub header {
    my $self   = shift;
    my $header = shift;

    if (@_) {
        $self->{headers}->header( $header => @_ );
    }
    else {
        return $self->{headers}->header($header);
    }
}

sub push_header {
    my $self   = shift;
    my $header = shift;

    if (@_) {
        foreach my $h(@_) {
            $self->{headers}->push_header( $header => $h );
        }
    }
    else {
        return $self->{headers}->header($header);
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
                ( $k => $v )
            } $self->{headers}->header($_);
          } $self->{headers}->header_field_names
    ];

    return $headers;
}

1;

