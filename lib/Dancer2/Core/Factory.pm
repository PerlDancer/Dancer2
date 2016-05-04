package Dancer2::Core::Factory;
# ABSTRACT: Instantiate components by type and name

use Moo;
use Dancer2::Core;
use Module::Runtime 'use_module';
use Carp 'croak';

sub create {
    my ( $class, $type, $name, %options ) = @_;

    $type = Dancer2::Core::camelize($type);
    $name = Dancer2::Core::camelize($name);
    my $component_class = "Dancer2::${type}::${name}";

    eval { use_module($component_class); 1; }
        or croak "Unable to load class for $type component $name: $@";

    return $component_class->new(%options);
}

1;
