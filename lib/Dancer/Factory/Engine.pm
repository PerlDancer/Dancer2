package Dancer::Factory::Engine;
use strict;
use warnings;

use Carp 'croak';

sub create {
    my ($class, $type, $name, %options) = @_;

    $type = _camelize($type);
    $name = _camelize($name);
    my $engine_class = "Dancer::${type}::${name}";
    
    eval "use $engine_class";
    croak "Unable to load class for $type engine $name: $@" if $@;

    return $engine_class->new(%options);
}

sub _camelize { ( my $v = $_[0] ) =~ s/(?:^|_)(.)/uc($1)/ge; $v }


1;
