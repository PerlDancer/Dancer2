# ABSTRACT: Serializer for handling JSON data

package Dancer2::Serializer::JSON;
use Moo;
use JSON ();

with 'Dancer2::Core::Role::Serializer';

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn Perl data structures into JSON output and vice-versa.

=cut

# helpers
sub from_json {
    my $s = Dancer2::Serializer::JSON->new;
    $s->deserialize(@_);
}

sub to_json {
    my $s = Dancer2::Serializer::JSON->new;
    $s->serialize(@_);
}

# class definition
sub loaded {1}

=method serialize

Serialize a Perl data structure into a JSON string.

=cut


sub serialize {
    my ( $self, $entity, $options ) = @_;

    # Why doesn't $self->config have this?
    my $config = $self->config;

    if ( $config->{allow_blessed} && !defined $options->{allow_blessed} ) {
        $options->{allow_blessed} = $config->{allow_blessed};
    }
    if ( $config->{convert_blessed} ) {
        $options->{convert_blessed} = $config->{convert_blessed};
    }
    $options->{utf8} = 1 if !defined $options->{utf8};

    JSON::to_json( $entity, $options );
}

=method deserialize

Deserialize a JSON string into a Perl data structure

=cut

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    $options->{utf8} = 1 if !defined $options->{utf8};
    JSON::from_json( $entity, $options );
}

=method content_type

return 'application/json'

=cut

sub content_type {'application/json'}

1;

