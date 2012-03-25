package Dancer::Serializer::Dumper;

use Moo;
use Carp 'croak';
use Data::Dumper;


with 'Dancer::Core::Role::Serializer';


# helpers

sub from_dumper {
    my $s = Dancer::Serializer::Dumper->new;
    $s->deserialize(@_);
}

sub to_dumper {
    my $s = Dancer::Serializer::Dumper->new;
    $s->serialize(@_);
}

# class definition

sub BUILD { eval "use Data::Dumper ()"; croak "Fail to load Dumper : $@" if $@ }
sub loaded { 1 }

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

sub content_type {'text/x-data-dumper'}

1;

=head1 NAME

Dancer::Serializer::Dumper - serializer for handling Dumper data

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 serialize

Serialize a data structure to a Dumper structure.

=head2 deserialize

Deserialize a Dumper structure to a data structure

=head2 content_type

Return 'text/x-data-dumper'

=cut
