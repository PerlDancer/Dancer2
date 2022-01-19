package Dancer2::ConfigReader::FileExtended;

use Moo;
use Dancer2::Core::Types;

use Carp 'croak';

extends 'Dancer2::ConfigReader::FileSimple';

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 0,
    default => sub {'FileExtended'},
);

around read_config => sub {
    my ($orig, $self) = @_;
    my $config = $orig->($self, @_);
    $self->_replace_env_vars($config);
    return $config;
};

# Attn. We are traversing along the original data structure all the time,
# using references, and changing values on the spot, not returning anything.
sub _replace_env_vars {
    my ( $self, $entry ) = @_;
    if( ref $entry ne 'HASH' && ref $entry ne 'ARRAY' ) {
        croak 'Param entry is not HASH or ARRAY';
    }
    if( ref $entry eq 'HASH' ) {
        foreach my $value (values %{ $entry }) {
            if( (ref $value) =~ m/(HASH|ARRAY)/msx ) {
                    $self->_replace_env_vars( $value );
                } elsif( (ref $value) =~ m/(CODE|REF|GLOB)/msx ) {
                    # Pretty much anything else except SCALAR. Do nothing
                    1;
                } else {
                    if( $value ) {
                        while( my ($k, $v) = each %ENV) {
                            $value =~ s/ \$ [{] ENV:$k [}] /$v/gmsx;
                        }
                    }
                }
            }
        } else {
            # ref $entry is 'ARRAY'
            foreach my $value (@{ $entry }) {
                if( (ref $value) =~ m/(HASH|ARRAY)/msx ) {
                        $self->_replace_env_vars( $value );
                } elsif( (ref $value) =~ m/(CODE|REF|GLOB)/msx ) {
                    # Pretty much anything else except SCALAR. Do nothing
                    1;
                } else {
                    if( $value ) {
                        while( my ($k, $v) = each %ENV) {
                            $value =~ s/ \$ [{] ENV:$k [}] /$v/gmsx;
                        }
                    }
                }
            }
        }
    return;
}

1;
