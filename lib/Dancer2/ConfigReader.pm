# ABSTRACT: Config reader for Dancer2 App
package Dancer2::ConfigReader;

use Moo;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime qw{ use_module };

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::ConfigUtils 'normalize_config_entry';

has location => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has default_config => (
    is      => 'ro',
    isa     => HashRef,
    required => 1,
);

has config_location => (
    is      => 'ro',
    isa     => ReadableFilePath,
    lazy    => 1,
    default => sub { $_[0]->location },
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
          || File::Spec->catdir( $_[0]->config_location, 'environments' );
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
    required => 1,
);

has config_readers => (
    is      => 'ro',
    lazy    => 1,
    #isa     => ArrayRef[ InstanceOf['Dancer2::Core::Role::ConfigReader'] ],
    isa     => ArrayRef,
    builder => '_build_config_readers',
);

# The config builder
sub _build_config {
    my ($self) = @_;

    my $default  = $self->default_config;
    use Data::Dumper;
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

sub _normalize_config {
    my ( $self, $config ) = @_;

    foreach my $key ( keys %{$config} ) {
        my $value = $config->{$key};
        $config->{$key} = normalize_config_entry( $key, $value );
    }
    return $config;
}

sub _build_config_readers {
    my ($self) = @_;

    my @config_reader_names = $ENV{'DANCER_CONFIG_READERS'}
                            ? (split qr{ \s+ }msx, $ENV{'DANCER_CONFIG_READERS'})
                            : ( q{Dancer2::ConfigReader::File::Simple} );

    warn "ConfigReaders to use: @config_reader_names\n" if $ENV{DANCER_CONFIG_VERBOSE};
    return [
        map use_module($_)->new(
            location    => $self->location,
            environment => $self->environment,
        ), @config_reader_names
    ];
}

1;

__END__

=head1 DESCRIPTION

This class provides a C<config> attribute that - when accessing
the first time - feeds itself by executing one or more
B<ConfigReader> packages.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

You can control which B<ConfigReader>
class or classes to use to create the config.

Use C<DANCER_CONFIG_READERS> environment variable to define
which class or classes you want.

    DANCER_CONFIG_READERS='Dancer2::ConfigReader::File::Simple Dancer2::ConfigReader::CustomConfig'

If you want several, separate them with whitespace.
Configs are added in left-to-write order where the previous
config items get overwritten by subsequent ones.

For example, if config

    item1: content1
    item2: content2
    item3:
        subitem1: subcontent1
        subitem2: subcontent2
        subitem3:
            subsubitem1:
                subsubcontent1
    item4:
        subitem1: subcontent1
        subitem2: subcontent2

was followed by config

    item2: content9
    item3:
        subitem2: subcontent8
        subitem3:
            subsubitem1:
                subsubcontent7
        subitem4:
            subsubitem5: subsubcontent5
    item4: content4

then the final config would be

    item1: content1
    item2: content9
    item3:
        subitem1: subcontent1
        subitem2: subcontent8
        subitem3:
            subsubitem1:
                subsubcontent7
        subitem4:
            subsubitem5: subsubcontent5
    item4: content4

The default B<ConfigReader> is C<Dancer2::ConfigReader::File::Simple>.

You can also create your own custom B<ConfigReader> classes.

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

Another (more complex) example is in the file C<Dancer2::ConfigReader::File::Simple>.

=head1 ATTRIBUTES

=attr location

Absolute path to the directory where the server started.

=attr config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=attr environments_location

Gets the directory where the environment files are stored.

=attr config

Returns the whole configuration.
This must not be used directly.
Instead, use this via C<Dancer2::Core::Role::HasConfig> role
which manages configuration after it is created.

=attr environment

Returns the name of the environment.
