# ABSTRACT: TODO

package Dancer::Serializer::JSON;
use Moo;
use JSON;

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
sub loaded {1}

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

    to_json( $entity, $options );
}

sub deserialize {
    my ($self, $entity, $options) = @_;
    from_json( $entity, $options );
}

sub content_type {'application/json'}

1;
