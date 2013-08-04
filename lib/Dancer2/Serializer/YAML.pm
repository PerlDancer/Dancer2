# ABSTRACT: Serializer for handling YAML data

package Dancer2::Serializer::YAML;
use Moo;
use Carp 'croak';
with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (default => 'text/x-yaml');

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

sub BUILD { eval "use YAML::Any ()"; croak "Fail to load YAML: $@" if $@ }
sub loaded {1}

sub serialize {
    my ( $self, $entity ) = @_;
    YAML::Any::Dump($entity);
}

sub deserialize {
    my ( $self, $content ) = @_;
    YAML::Any::Load($content);
}

1;

__END__

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
YAML output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'text/x-yaml'

=method serialize($content)

Serializes a data structure to a YAML structure.

=method deserialize($content)

Deserializes a YAML structure to a data structure.

