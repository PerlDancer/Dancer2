package Dancer2::Serializer::YAML;
# ABSTRACT: Serializer for handling YAML data
$Dancer2::Serializer::YAML::VERSION = '0.159002';
use Moo;
use Carp 'croak';
use Encode;
use Class::Load 'load_class';
with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'text/x-yaml'} );

# helpers
sub from_yaml {
    my ($yaml) = @_;
    my $s = Dancer2::Serializer::YAML->new;
    $s->deserialize($yaml);
}

sub to_yaml {
    my ($data) = @_;
    my $s = Dancer2::Serializer::YAML->new;
    $s->serialize($data);
}

# class definition
sub BUILD { load_class('YAML') }

sub serialize {
    my ( $self, $entity ) = @_;
    encode('UTF-8', YAML::Dump($entity));
}

sub deserialize {
    my ( $self, $content ) = @_;
    YAML::Load(decode('UTF-8', $content));
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Serializer::YAML - Serializer for handling YAML data

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
YAML output and vice-versa.

=head1 ATTRIBUTES

=head2 content_type

Returns 'text/x-yaml'

=head1 METHODS

=head2 serialize($content)

Serializes a data structure to a YAML structure.

=head2 deserialize($content)

Deserializes a YAML structure to a data structure.

=head1 FUNCTIONS

=head2 fom_yaml($content)

This is an helper available to transform a YAML data structure to a Perl data structures.

=head2 to_yaml($content)

This is an helper available to transform a Perl data structure to YAML.

Calling this function will B<not> trigger the serialization's hooks.

=head1 METHODS

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
