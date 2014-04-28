package Dancer2::Core::Factory;
# ABSTRACT: Instantiate components by type and name

use strict;
use warnings;

use Dancer2::Core;
use Class::Load 'try_load_class';
use Carp 'croak';

sub create {
    my ( $class, $type, $name, %options ) = @_;

    $type = Dancer2::Core::camelize($type);
    $name = Dancer2::Core::camelize($name);
    my $component_class = "Dancer2::${type}::${name}";

    my ( $ok, $error ) = try_load_class($component_class);
    $ok or croak "Unable to load class for $type component $name: $error";

    return $component_class->new(%options);
}

1;
