# ABSTRACT: Config role for Dancer2 core objects
package Dancer2::Core::Role::ConfigReader;

use Moo::Role;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime 'require_module';

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::FileUtils 'path';

with 'Dancer2::Core::Role::HasLocation';

has default_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_default_config',
);

has config_location => (
    is      => 'ro',
    isa     => ReadableFilePath,
    lazy    => 1,
    default => sub { $ENV{DANCER_CONFDIR} || $_[0]->location },
);

# The type for this attribute is Str because we don't require
# an existing directory with configuration files for the
# environments.  An application without environments is still
# valid and works.
has environments_location => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub {
        $ENV{DANCER_ENVDIR}
          || File::Spec->catdir( $_[0]->config_location, 'environments' )
          || File::Spec->catdir( $_[0]->location,        'environments' );
    },
);

has config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
);

has environment => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_environment',
);

has config_files => (
    is      => 'ro',
    lazy    => 1,
    isa     => ArrayRef,
    builder => '_build_config_files',
);

has local_triggers => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { +{} },
);

has global_triggers => (
    is      => 'ro',
    isa     => HashRef,
    default => sub {
        my $triggers = {
            traces => sub {
                my ( $self, $traces ) = @_;
                # Carp is already a dependency
                $Carp::Verbose = $traces ? 1 : 0;
            },
        };

        my $runner_config = defined $Dancer2::runner
                            ? Dancer2->runner->config
                            : {};

        for my $global ( keys %$runner_config ) {
            next if exists $triggers->{$global};
            $triggers->{$global} = sub {
                my ($self, $value) = @_;
                Dancer2->runner->config->{$global} = $value;
            }
        }

        return $triggers;
    },
);

sub _build_default_config { +{} }

sub _build_environment { 'development' }

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

sub _build_config {
    my ($self) = @_;

    my $location = $self->config_location;
    my $default  = $self->default_config;

    my $config = Hash::Merge::Simple->merge(
        $default,
        map {
            warn "Merging config file $_\n" if $ENV{DANCER_CONFIG_VERBOSE};
            $self->load_config_file($_) 
        } @{ $self->config_files }
    );

    $config = $self->_normalize_config($config);
    return $config;
}

sub _set_config_entries {
    my ( $self, @args ) = @_;
    my $no = scalar @args;
    while (@args) {
        $self->_set_config_entry( shift(@args), shift(@args) );
    }
    return $no;
}

sub _set_config_entry {
    my ( $self, $name, $value ) = @_;

    $value = $self->_normalize_config_entry( $name, $value );
    $value = $self->_compile_config_entry( $name, $value, $self->config );
    $self->config->{$name} = $value;
}

sub _normalize_config {
    my ( $self, $config ) = @_;

    foreach my $key ( keys %{$config} ) {
        my $value = $config->{$key};
        $config->{$key} = $self->_normalize_config_entry( $key, $value );
    }
    return $config;
}

sub _compile_config {
    my ( $self, $config ) = @_;

    foreach my $key ( keys %{$config} ) {
        my $value = $config->{$key};
        $config->{$key} =
          $self->_compile_config_entry( $key, $value, $config );
    }
    return $config;
}

sub settings { shift->config }

sub setting {
    my $self = shift;
    my @args = @_;

    return ( scalar @args == 1 )
      ? $self->settings->{ $args[0] }
      : $self->_set_config_entries(@args);
}

sub has_setting {
    my ( $self, $name ) = @_;
    return exists $self->config->{$name};
}

sub load_config_file {
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

# private

my $_normalizers = {
    charset => sub {
        my ($charset) = @_;
        return $charset if !length( $charset || '' );

        require_module('Encode');
        my $encoding = Encode::find_encoding($charset);
        croak
          "Charset defined in configuration is wrong : couldn't identify '$charset'"
          unless defined $encoding;
        my $name = $encoding->name;

        # Perl makes a distinction between the usual perl utf8, and the strict
        # utf8 charset. But we don't want to make this distinction
        $name = 'utf-8' if $name eq 'utf-8-strict';
        return $name;
    },
};

sub _normalize_config_entry {
    my ( $self, $name, $value ) = @_;
    $value = $_normalizers->{$name}->($value)
      if exists $_normalizers->{$name};
    return $value;
}

sub _compile_config_entry {
    my ( $self, $name, $value, $config ) = @_;

    my $trigger = exists $self->local_triggers->{$name} ?
                         $self->local_triggers->{$name} :
                         $self->global_triggers->{$name};

    defined $trigger or return $value;

    return $trigger->( $self, $value, $config );
}

1;

__END__

=head1 DESCRIPTION

Provides a C<config> attribute that feeds itself by finding and parsing
configuration files.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

=head1 ATTRIBUTES

=attr location

Absolute path to the directory where the server started.

=attr config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=attr environments_location

Gets the directory were the environment files are stored.

=attr config

Returns the whole configuration.

=attr environments

Returns the name of the environment.

=attr config_files

List of all the configuration files.

=head1 METHODS

=head2 settings

Alias for config. Equivalent to <<$object->config>>.

=head2 setting

Get or set an element from the configuration.

=head2 has_setting

Verifies that a key exists in the configuration.

=head2 load_config_file

Load the configuration files.
