package Dancer2::Serializer::JSON;
# ABSTRACT: Serializer for handling JSON data

use Moo;
use JSON::MaybeXS ();
use Scalar::Util 'blessed';

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'application/json'} );

# helpers
sub from_json { __PACKAGE__->deserialize(@_) }

sub to_json { __PACKAGE__->serialize(@_) }

# class definition
sub serialize {
    my ( $self, $entity, $options ) = @_;

    my $config = blessed $self ? $self->config : {};

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless exists $options->{$_};
    }

    $options->{utf8} = 1 if !defined $options->{utf8};
    JSON::MaybeXS->new($options)->encode($entity);
}

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    $options->{utf8} = 1 if !defined $options->{utf8};
    JSON::MaybeXS->new($options)->decode($entity);
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
