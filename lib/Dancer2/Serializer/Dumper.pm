# ABSTRACT: Serializer for handling Dumper data

package Dancer2::Serializer::Dumper;

use Moo;
use Carp 'croak';
use Data::Dumper;
use Safe;

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'text/x-data-dumper'} );

# helpers
sub from_dumper { __PACKAGE__->deserialize(@_) }

sub to_dumper { __PACKAGE__->serialize(@_) }

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

    my $cpt = Safe->new;

    my $res = $cpt->reval("my \$VAR1; $content");
    croak "unable to deserialize : $@" if $@;
    return $res;
}

1;

__END__

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures  into
L<Data::Dumper> output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'text/x-data-dumper'

=func from_dumper($content)

This is an helper available to transform a L<Data::Dumper> output to a Perl
data structures.

=func to_dumper($content)

This is an helper available to transform a Perl data structures to a
L<Data::Dumper> output.

Calling this function will B<not> trigger the serialization's hooks.

=method serialize($content)

Serializes a Perl data structure into a Dumper string.

=method deserialize($content)

Deserialize a Dumper string into a Perl data structure.
