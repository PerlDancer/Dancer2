package Dancer2::Serializer::YAML;
# ABSTRACT: Serializer for handling YAML data

use Moo;
use Carp 'croak';
use Encode;
use Module::Runtime 'use_module';
use Sub::Defer;

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'text/x-yaml'} );

# deferred helpers. These are called as class methods, but need to
# ensure YAML is loaded.

my $_from_yaml = defer_sub 'Dancer2::Serializer::YAML::from_yaml' => sub {
    use_module('YAML');
    sub { __PACKAGE__->deserialize(@_) };
};

my $_to_yaml = defer_sub 'Dancer2::Serializer::YAML::to_yaml' => sub {
    use_module('YAML');
    sub { __PACKAGE__->serialize(@_) };
};

# class definition
sub BUILD { use_module('YAML') }

sub serialize {
    my ( $self, $entity ) = @_;
    encode('UTF-8', YAML::Dump($entity));
}

sub deserialize {
    my ( $self, $content ) = @_;

    # Content reaching here is untrusted -- for an app with 'serializer: YAML'
    # (or Serializer::Mutable, which maps both text/x-yaml and text/html to
    # this class) it is the raw request body.
    #
    # YAML tags can ask the loader to build things that are not data.
    # !!perl/hash:Some::Class instantiates an arbitrary blessed object, which
    # is the entry point for DESTROY/AUTOLOAD gadget chains, and !!perl/code
    # asks for a string eval. Both are refused here.
    #
    # These are set explicitly rather than left to YAML.pm's defaults so the
    # behaviour does not depend on which YAML.pm the user resolved: LoadBlessed
    # only defaults to 0 from YAML 1.30, and the variable itself only exists
    # from 1.25 (which is why cpanfile floors YAML -- see the note there).
    local $YAML::LoadBlessed = 0;
    local $YAML::LoadCode    = 0;

    YAML::Load(decode('UTF-8', $content));
}

1;

__END__

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
YAML output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'text/x-yaml'

=func fom_yaml($content)

This is an helper available to transform a YAML data structure to a Perl data structures.

=func to_yaml($content)

This is an helper available to transform a Perl data structure to YAML.

Calling this function will B<not> trigger the serialization's hooks.

=method serialize($content)

Serializes a data structure to a YAML structure.

=method deserialize($content)

Deserializes a YAML structure to a data structure.
