package Dancer2::Core;
# ABSTRACT: Core libraries for Dancer2 2.0
$Dancer2::Core::VERSION = '0.159002';
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

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core - Core libraries for Dancer2 2.0

=head1 VERSION

version 0.159002

=head1 FUNCTIONS

=head2 camelize

Camelize a underscore-separated-string.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
