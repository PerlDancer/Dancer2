package Dancer2::Serializer::JSON;
# ABSTRACT: Serializer for handling JSON data

use Moo;
use JSON ();

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (default => 'application/json');

# helpers
# Do not use (de)serialize(), since they are wrapped to trap exceptions
sub from_json {
    my ( $entity, $options ) = @_;

    my $s = Dancer2::Serializer::JSON->new;
    JSON::from_json( $entity, $s->_merge_options($options) );
}

sub to_json {
    my ( $entity, $options ) = @_;

    my $s = Dancer2::Serializer::JSON->new;
    JSON::to_json( $entity, $s->_merge_options($options) );
}

# class definition
sub loaded {1}

sub _merge_options {
    my ( $self, $options ) = @_;

    my $config = $self->config;

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless exists $options->{$_};
    }

    $options->{utf8} = 1 if !defined $options->{utf8};

    $options;
}

sub serialize {
    my ( $self, $entity, $options ) = @_;

    JSON::to_json( $entity, $self->_merge_options($options) );
}

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    JSON::from_json( $entity, $self->_merge_options($options) );
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
