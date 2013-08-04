# ABSTRACT: Serializer for handling Dumper data

package Dancer2::Serializer::Dumper;

use Moo;
use Carp 'croak';
use Data::Dumper;

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (default => 'text/x-data-dumper');

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

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures  into
L<Data::Dumper> output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'text/x-data-dumper'

=method serialize($content)

Serializes a Perl data structure into a Dumper string.

=method deserialize($content)

Deserialize a Dumper string into a Perl data structure.
