# ABSTRACT: Config role for Dancer2 core objects
package Dancer2::Core::Role::Config;

use Moo::Role;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime qw{ require_module use_module };

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

has config_readers => (
    is      => 'ro',
    lazy    => 1,
    isa     => ArrayRef,
    builder => '_build_config_readers',
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

        no warnings 'once'; # Disable: Name "Dancer2::runner" used only once: possible typo
        my $runner_config = defined $Dancer2::runner
                            ? Dancer2->runner->config
                            : {};
        use warnings 'once';

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

    return [ map {
            warn "Merging config_files from @{[ $_->name() ]}\n" if $ENV{DANCER_CONFIG_VERBOSE};
            @{ $_->config_files() }
        } @{ $self->config_readers }
    ];
}

# The new config builder
sub _build_config {
    my ($self) = @_;

    my $default  = $self->default_config;
    my $config = Hash::Merge::Simple->merge(
        $default,
        map {
            warn "Merging config from @{[ $_->name() ]}\n" if $ENV{DANCER_CONFIG_VERBOSE};
            $_->read_config()
        } @{ $self->config_readers }
    );

    $config = $self->_normalize_config($config);
    return $config;
}

sub _build_config_readers {
    my ($self) = @_;

    my @config_reader_names = $ENV{'DANCER_CONFIG_READERS'}
                            ? (split qr{ [[:space:]]{1,} }msx, $ENV{'DANCER_CONFIG_READERS'})
                            : ( q{Dancer2::ConfigReader::File::Simple} );

    return [ map {
        use_module($_)->new(
            location => $self->location,
            environment => $self->environment,
            );
    } @config_reader_names ];
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

This is the redesigned C<Dancer2::Core::Role::ConfigReader>
to manage the Dancer2 configuration.

It is now possible for user to control which B<ConfigReader>
class to use to create the config.

Use C<DANCER_CONFIG_READERS> environment variable to define
which class or classes you want.

    DANCER_CONFIG_READERS='Dancer2::ConfigReader::File::Simple Dancer2::ConfigReader::CustomConfig'

If you want several, separate them with whitespace.
Configs are read in left-to-write order where the previous
config items get overwritten by subsequent ones.

You can create your own custom B<ConfigReader>.
The default is to use C<Dancer2::ConfigReader::File::Simple>
which was the only way to read config files earlier.

If you want, you can also extend class C<Dancer2::ConfigReader::File::Simple>.
Here is an example:

    package Dancer2::ConfigReader::FileExtended;
    use Moo;
    extends 'Dancer2::ConfigReader::File::Simple';
    has name => (
        is      => 'ro',
        default => sub {'FileExtended'},
    );
    around read_config => sub {
        my ($orig, $self) = @_;
        my $config = $orig->($self, @_);
        $config->{'dummy'}->{'item'} = 123;
        return $config;
    };


Provides a C<config> attribute that - when accessing
the first time - feeds itself by executing one or more
B<ConfigReader> packages.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

=head1 ATTRIBUTES

=attr location

Absolute path to the directory where the server started.

=attr config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=attr environments_location

Gets the directory where the environment files are stored.

=attr config

Returns the whole configuration.

=attr environment

Returns the name of the environment.

=attr config_files

List of all the configuration files. This information
is queried from the B<ConfigReader> classes.

=head1 METHODS

=head2 settings

Alias for config. Equivalent to <<$object->config>>.

=head2 setting

Get or set an element from the configuration.

=head2 has_setting

Verifies that a key exists in the configuration.
