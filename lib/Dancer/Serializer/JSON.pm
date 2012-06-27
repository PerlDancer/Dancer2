# ABSTRACT: TODO

package Dancer::Serializer::JSON;
use Moo;
use Carp 'croak';

with 'Dancer::Core::Role::Serializer';


# helpers

sub from_json {
    my $s = Dancer::Serializer::JSON->new;
    $s->deserialize(@_);
}

sub to_json {
    my $s = Dancer::Serializer::JSON->new;
    $s->serialize(@_);
}

# class definition

sub loaded { require 'JSON.pm'; }

sub serialize {
    my ($self, $entity, $options) = @_;

    # Why doesn't $self->config have this?
    my $config = $self->config;

    if ( $config->{allow_blessed} && !defined $options->{allow_blessed} ) {
        $options->{allow_blessed} = $config->{allow_blessed};
    }
    if ( $config->{convert_blessed} ) {
        $options->{convert_blessed} = $config->{convert_blessed};
    }

    require 'JSON.pm';
    JSON::to_json( $entity, $options );
}

sub deserialize {
    my ($self, $entity, $options) = @_;
    require 'JSON.pm';
    JSON::from_json( $entity, $options );
}

sub content_type {'application/json'}

1;

__END__

=pod

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn Perl data structures into JSON output and vice-versa.

=head1 METHODS

=head2 serialize

Serialize a Perl data structure into a JSON string.

=head2 deserialize

Deserialize a JSON string into a Perl data structure

=head2 content_type

return 'application/json'

=cut

