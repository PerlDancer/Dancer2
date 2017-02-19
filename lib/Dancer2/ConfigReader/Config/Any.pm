# ABSTRACT: Config reader for files
package Dancer2::ConfigReader::Config::Any;

use Moo;

use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime 'require_module';

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Path::Tiny qw< path >;

with 'Dancer2::Core::Role::ConfigReader';

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 0,
    default => sub {'Config::Any'},
);

has config_files => (
    is      => 'ro',
    lazy    => 1,
    isa     => ArrayRef,
    builder => '_build_config_files',
);

sub read_config {
    my ($self) = @_;

    my $config = Hash::Merge::Simple->merge(
        map {
            warn "Merging config file $_\n" if $ENV{DANCER_CONFIG_VERBOSE};
            $self->_load_config_file($_)
        } @{ $self->config_files }
    );

    return $config;
}

sub _build_config_files {
    my ($self) = @_;

    my $location = $self->config_location;
    warn "Searching config files in location: $location\n" if $ENV{DANCER_CONFIG_VERBOSE};
    # an undef location means no config files for the caller
    return [] unless defined $location;

    my $running_env = $self->environment;
    my @available_exts = Config::Any->extensions;
    my @files;

    my @exts = @available_exts;
    if (my $ext = $ENV{DANCER_CONFIG_EXT}) {
        if (grep { $ext eq $_ } @available_exts) {
            @exts = $ext;
            warn "Only looking for configs ending in '$ext'\n"
                if $ENV{DANCER_CONFIG_VERBOSE};
        } else {
            warn "DANCER_CONFIG_EXT environment variable set to '$ext' which\n" .
                 "is not recognized by Config::Any. Looking for config file\n" .
                 "using default list of extensions:\n" .
                 "\t@available_exts\n";
        }
    }

    foreach my $file ( [ $location, "config" ],
        [ $self->environments_location, $running_env ] )
    {
        foreach my $ext (@exts) {
            my $path = Path::Tiny::path( $file->[0], $file->[1] . ".$ext" )->stringify;
            next if !-r $path;

            # Look for *_local.ext files
            my $local = Path::Tiny::path( $file->[0], $file->[1] . "_local.$ext" );
            push @files, $path, ( -r $local ? $local : () );
        }
    }

    warn "Found following config files: @files\n" if $ENV{DANCER_CONFIG_VERBOSE};
    return \@files;
}

sub _load_config_file {
    my ( $self, $file ) = @_;
    my $config;

    eval {
        my @files = ($file);
        my $tmpconfig =
          Config::Any->load_files( { files => \@files, use_ext => 1 } )->[0];
        ( $file, $config ) = %{$tmpconfig} if defined $tmpconfig;
    };
    if ( my $err = $@ || ( !$config ) ) {
        croak "Unable to parse the configuration file: $file: $@";
    }

    # TODO handle mergeable entries
    return $config;
}

1;

__END__

=head1 DESCRIPTION

This class is an implementation of C<Dancer2::Core::Role::ConfigReader>.
It reads the configuration files of C<Dancer2>.

Please see C<Dancer2::Config> for more information.

If you need to add additional functionality to the reading
mechanism, you can extend this class.
An example of this is providing the possibility to replace
random parts of the file config with environmental variables:

    package Dancer2::ConfigReader::File::Extended;

    use Moo;
    use Dancer2::Core::Types;

    use Carp 'croak';

    extends 'Dancer2::ConfigReader::Config::Any';

    has name => (
        is      => 'ro',
        isa     => Str,
        lazy    => 0,
        default => sub {'File::Extended'},
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

=head1 ATTRIBUTES

=attr name

The name of the Config Reader class: C<Config::Any>.

=attr location

Absolute path to the directory where the server started.

=attr config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=attr environments_location

Gets the directory where the environment files are stored.

=attr environment

Returns the name of the environment.

=attr config_files

List of all the configuration files.

=head1 METHODS

=head2 read_config

Load the configuration files.
