# ABSTRACT: Core libraries for Dancer2 2.0

package Dancer2::Core;

use strict;
use warnings;

=func camelize

Camelize a underscore-separated-string.

=cut

sub camelize {
    my ($value) = @_;

    my $camelized = '';
    for my $word ( split /_/, $value ) {
        $camelized .= ucfirst($word);
    }
    return $camelized;
}


1;
