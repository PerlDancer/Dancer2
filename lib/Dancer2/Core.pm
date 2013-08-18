# ABSTRACT: Core libraries for Dancer2 2.0

package Dancer2::Core;

use strict;
use warnings;

=func debug

Output a message to STDERR and take further arguments as some data structures using 
L<Data::Dumper>

=cut

sub debug {
    return unless $ENV{DANCER_DEBUG_CORE};

    my $msg = shift;
    my (@stuff) = @_;

    my $vars = @stuff ? Dumper( \@stuff ) : '';

    my ( $package, $filename, $line ) = caller;

    chomp $msg;
    print STDERR "core: $msg\n$vars";
}

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
