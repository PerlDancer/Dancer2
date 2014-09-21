package Dancer2::Core;
# ABSTRACT: Core libraries for Dancer2 2.0

use strict;
use warnings;

sub camelize {
    my ($value) = @_;

    my $camelized = '';
    for my $word ( split /_/, $value ) {
        $camelized .= ucfirst($word);
    }
    return $camelized;
}


1;

__END__

=func camelize

Camelize a underscore-separated-string.

=cut
