package Dancer2::ConfigReader::File::Simple;

use Moo;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime 'require_module';

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::FileUtils 'path';

with 'Dancer2::Core::Role::ConfigReader';

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 0,
    default => sub {'File::Simple'},
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
            my $path = path( $file->[0], $file->[1] . ".$ext" );
            next if !-r $path;

            # Look for *_local.ext files
            my $local = path( $file->[0], $file->[1] . "_local.$ext" );
            push @files, $path, ( -r $local ? $local : () );
        }
    }

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

This class provides the same features to read configuration files
as were earlier done by C<Dancer2::Core::Role::Config>.

If you need to add additional functionality to the reading
mechanism, you can extend this class. An example of this is
in: B</t/lib/Dancer2/ConfigReader/File/Extended.pm>

=head1 ATTRIBUTES

=attr name

The name of the class.

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
