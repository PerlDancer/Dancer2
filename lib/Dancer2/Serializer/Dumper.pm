# ABSTRACT: Serializer for handling Dumper data

package Dancer2::Serializer::Dumper;
$Dancer2::Serializer::Dumper::VERSION = '0.159002';
use Moo;
use Carp 'croak';
use Data::Dumper;

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'text/x-data-dumper'} );

# helpers
sub from_dumper {
    my $s = Dancer2::Serializer::Dumper->new;
    $s->deserialize(@_);
}

sub to_dumper {
    my $s = Dancer2::Serializer::Dumper->new;
    $s->serialize(@_);
}

# class definition
sub serialize {
    my ( $self, $entity ) = @_;

    {
        local $Data::Dumper::Purity = 1;
        return Dumper($entity);
    }
}

sub deserialize {
    my ( $self, $content ) = @_;

    my $res = eval "my \$VAR1; $content";
    croak "unable to deserialize : $@" if $@;
    return $res;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Serializer::Dumper - Serializer for handling Dumper data

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures  into
L<Data::Dumper> output and vice-versa.

=head1 ATTRIBUTES

=head2 content_type

Returns 'text/x-data-dumper'

=head1 METHODS

=head2 serialize($content)

Serializes a Perl data structure into a Dumper string.

=head2 deserialize($content)

Deserialize a Dumper string into a Perl data structure.

=head1 FUNCTIONS

=head2 from_dumper($content)

This is an helper available to transform a L<Data::Dumper> output to a Perl
data structures.

=head2 to_dumper($content)

This is an helper available to transform a Perl data structures to a
L<Data::Dumper> output.

Calling this function will B<not> trigger the serialization's hooks.

=head1 METHODS

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
