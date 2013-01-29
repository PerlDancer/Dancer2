# ABSTRACT: Instantiate components by type and name

package Dancer::Core::Factory;
use strict;
use warnings;

use Dancer::ModuleLoader;
use Carp 'croak';

sub create {
    my ($class, $type, $name, %options) = @_;

    $type = _camelize($type);
    $name = _camelize($name);
    my $component_class = "Dancer::${type}::v2::${name}";

    my ($ok, $error) = Dancer::ModuleLoader->require($component_class);
    if ( ! $ok ) {
        croak "Unable to load class for $type component $name: $error";
    }

    return $component_class->new(%options);
}

sub _camelize {
    my ($value) = @_;

    my $camelized = '';
    for my $word (split /_/, $value) {
        $camelized .= ucfirst($word);
    }
    return $camelized;
}

1;
