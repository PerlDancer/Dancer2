# ABSTRACT: Serializer for handling Dumper data

package Dancer2::Serializer::Dumper;

use Moo;
use Carp 'croak';
use Data::Dumper;

with 'Dancer2::Core::Role::Serializer';

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn Perl data structures into L<Data::Dumper> output and vice-versa.

=cut


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
sub loaded {1}

=method serialize

Serialize a Perl data structure into a Dumper string.

=cut 

sub serialize {
    my ( $self, $entity ) = @_;

    {
        local $Data::Dumper::Purity = 1;
        return Dumper($entity);
    }
}

=method deserialize

Deserialize a Dumper string into a Perl data structure

=cut

sub deserialize {
    my ( $self, $content ) = @_;

    my $res = eval "my \$VAR1; $content";
    croak "unable to deserialize : $@" if $@;
    return $res;
}

=method content_type

Return 'text/x-data-dumper'

=cut

sub content_type {'text/x-data-dumper'}

1;

