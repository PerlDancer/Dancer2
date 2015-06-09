package Dancer2::Serializer::JSON;
# ABSTRACT: Serializer for handling JSON data
$Dancer2::Serializer::JSON::VERSION = '0.159002';
use Moo;
use JSON ();

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'application/json'} );

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
sub serialize {
    my ( $self, $entity, $options ) = @_;

    my $config = $self->config;

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless exists $options->{$_};
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

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Serializer::JSON - Serializer for handling JSON data

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
JSON output and vice-versa.

=head1 ATTRIBUTES

=head2 content_type

Returns 'application/json'

=head1 METHODS

=head2 serialize($content)

Serializes a Perl data structure into a JSON string.

=head2 deserialize($content)

Deserializes a JSON string into a Perl data structure.

=head1 FUNCTIONS

=head2 from_json($content, \%options)

This is an helper available to transform a JSON data structure to a Perl data structures.

=head2 to_json($content, \%options)

This is an helper available to transform a Perl data structure to JSON.

Calling this function will B<not> trigger the serialization's hooks.

=head1 METHODS

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
