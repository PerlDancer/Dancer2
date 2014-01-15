# ABSTRACT: Serializer for handling JSON data

package Dancer2::Serializer::JSON;
use Moo;
use JSON ();

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (default => 'application/json');

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

sub serialize {
    my ( $self, $entity, $options ) = @_;

    my $config = eval { $self->context->app->config->{engines}->{JSON} };

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless defined $options->{$_};
    }

    $options->{utf8} = 1 if !defined $options->{utf8};

    JSON::to_json( $entity, $options );
}

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    $options->{utf8} = 1 if !defined $options->{utf8};
    JSON::from_json( $entity, $options );
}

1;

__END__

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
JSON output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'application/json'

=func from_json($content, \%options)

This is an helper available to transform a JSON data structure to a Perl data structures.

=func to_json($content, \%options)

This is an helper available to transform a Perl data structure to JSON.

Calling this function will B<not> trigger the serialization's hooks.

=method serialize($content)

Serializes a Perl data structure into a JSON string.

=method deserialize($content)

Deserializes a JSON string into a Perl data structure.
