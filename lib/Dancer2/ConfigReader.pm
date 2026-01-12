# ABSTRACT: Config reader for Dancer2 App
package Dancer2::ConfigReader;

use Moo;

use File::Spec;
use Config::Any;
use Hash::Merge::Simple;
use Carp 'croak';
use Module::Runtime qw{ use_module };
use Ref::Util qw/ is_arrayref is_hashref /;
use Scalar::Util qw/ blessed /;

use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::ConfigUtils 'normalize_config_entry';

our $MAX_CONFIGS = $ENV{DANCER_MAX_CONFIGS} || 100;

my %KNOWN_CORE_KEYS = map +( $_ => 1 ), qw(
    additional_config_readers
    appdir
    apphandler
    appname
    auto_page
    behind_proxy
    charset
    content_type
    default_mime_type
    engines
    environment
    error_template
    host
    layout
    layout_dir
    log
    logger
    no_default_middleware
    no_server_tokens
    plugins
    port
    public_dir
    route_handlers
    serializer
    session
    show_errors
    show_stacktrace
    startup_info
    static_handler
    template
    timeout
    traces
    type_library
    views
    strict_config
);

my %KNOWN_ENGINE_CONFIG = (
    'logger' => {
        'base_keys' => {
            'app_name'              => 1,
            'auto_encoding_charset' => 1,
            'log_format'            => 1,
            'log_level'             => 1,
        },
        'engines' => {
            'capture' => { keys => {} },
            'console' => { keys => {} },
            'diag'    => { keys => {} },
            'file'    => {
                'keys' => {
                    'file_name' => 1,
                    'log_dir'   => 1,
                },
            },
            'note'    => { keys => {} },
            'null'    => { keys => {} },
        },
    },
    'serializer' => {
        'engines' => {
            'dumper' => { keys => {} },
            'json'   => { allow_any => 1 },
            'mutable' => {
                keys => {
                    mapping => 1,
                },
            },
            'yaml' => { keys => {} },
        },
    },
    'session' => {
        'base_keys' => {
            'cookie_domain'    => 1,
            'cookie_duration'  => 1,
            'cookie_name'      => 1,
            'cookie_path'      => 1,
            'cookie_same_site' => 1,
            'is_http_only'     => 1,
            'is_secure'        => 1,
            'session_duration' => 1,
        },
        'engines' => {
            'simple' => { keys => {} },
            'yaml'   => {
                'keys' => {
                    'session_dir' => 1,
                },
            },
        },
    },
    'template' => {
        'engines' => {
            'templatetoolkit' => { allow_any => 1 },
            'tiny'            => { allow_any => 1 },
        },
    },
);

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
    isa     => ArrayRef,
    builder => '_build_config_readers',
);

# The config builder
sub _build_config {
    my ($self) = @_;

    my $config  = $self->default_config;

    my $nbr_config = 0;

    my @readers = @{ $self->config_readers };

    my $config_to_object = sub {
        my $thing = $_;

        return $thing if blessed $thing;

        $thing = { $thing => {} } unless ref $thing;

        die "additional_config_readers entry must have exactly one key\n"
            if keys %$thing != 1;

        my( $class, $args ) = %$thing;

        return use_module($class)->new(
            location    => $self->location,
            environment => $self->environment,
            %$args,
        );
    };

    while( my $r = shift @readers ) {
        die <<"END" if $nbr_config++ >= $MAX_CONFIGS;
MAX_CONFIGS exceeded: read over $MAX_CONFIGS configurations

Looks like you have an infinite recursion in your configuration system.
Re-run with DANCER_CONFIG_VERBOSE=1 to see what is going on.

If your application really read that many configs (may \$dog have mercy
on your soul), you can increase the limit via the environment variable
DANCER_MAX_CONFIGS.

END
        warn "Reading config from @{[ $r->name() ]}\n" if $ENV{DANCER_CONFIG_VERBOSE};
        my $local_config = $r->read_config;

        if( my $additionals = delete $local_config->{additional_config_readers} ) {

            warn "Additional config readers found\n" if $ENV{DANCER_CONFIG_VERBOSE};

            unshift @readers, map { $config_to_object->($_) } is_arrayref($additionals) ? @$additionals : ($additionals);
        }

        $config = Hash::Merge::Simple->merge(
            $config, $local_config
        );
    }

    return $self->_normalize_config($config);
}

sub _normalize_config {
    my ( $self, $config ) = @_;

    foreach my $key ( keys %{$config} ) {
        my $value = $config->{$key};
        $config->{$key} = normalize_config_entry( $key, $value );
    }

    $self->_strict_config_keys($config);

    return $config;
}

sub _build_config_readers {
    my ($self) = @_;

    my @config_reader_names = $ENV{'DANCER_CONFIG_READERS'}
                            ? (split qr{,}msx, $ENV{'DANCER_CONFIG_READERS'})
                            : ( q{Dancer2::ConfigReader::Config::Any} );

    warn "ConfigReaders to use: @config_reader_names\n" if $ENV{DANCER_CONFIG_VERBOSE};
    return [
        map use_module($_)->new(
            location    => $self->location,
            environment => $self->environment,
        ), @config_reader_names
    ];
}

sub _strict_config_keys {
    my ( $self, $config ) = @_;

    return
        if exists $config->{'strict_config'}
        && !$config->{'strict_config'};

    my @warnings = map +(
        $KNOWN_CORE_KEYS{$_}
        ? ()
        : "Unknown configuration key '$_'"
    ), sort keys %{$config};

    if ( my $engines = $config->{'engines'} ) {
        push @warnings, $self->_warn_unknown_engine_config_keys($engines);
    }

    @warnings or return;

    warn join(
        "\n",
        @warnings,
        'Set strict_config => 0 to silence these warnings.'
    ) . "\n";
}

sub _warn_unknown_engine_config_keys {
    my ( $self, $engines ) = @_;
    is_hashref($engines)
        or return;

    my @warnings;

    for my $engine_type ( sort keys %{$engines} ) {
        my $type_config = $engines->{$engine_type};
        is_hashref($type_config)
            or next;

        my $known_type = $KNOWN_ENGINE_CONFIG{$engine_type}
            or next;

        my $base_keys     = $known_type->{'base_keys'} || {};
        my $known_engines = $known_type->{'engines'}   || {};

        for my $engine_name ( sort keys %{$type_config} ) {
            my $engine_config = $type_config->{$engine_name};
            is_hashref($engine_config)
                or next;

            my $normalized = _normalize_engine_name($engine_name);
            defined $normalized
                or next;

            my $known_engine = $known_engines->{$normalized} or next;
            next if $known_engine->{'allow_any'};

            my %allowed = (%{$base_keys}, %{ $known_engine->{keys} || {} });

            for my $key ( sort keys %{$engine_config} ) {
                next if $allowed{$key};
                push @warnings,
                    "Unknown configuration key '$key' for engine '$engine_type/$engine_name'";
            }
        }
    }

    return @warnings;
}

sub _normalize_engine_name {
    my ($name) = @_;

    return if !defined $name;
    return if $name =~ /::/xms;

    my $normalized = lc $name;
    $normalized =~ s/_//xmsg;
    return $normalized;
}

1;

__END__

=head1 DESCRIPTION

This class provides a C<config> attribute which is populated by executing
one or more B<ConfigReader> packages.

The default ConfigReader used is L<Dancer2::ConfigReader::Config::Any>.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

If more than one config reader is used, their configurations are merged
in left-to-write order where the previous config items get overwritten by subsequent ones.

For example, assuming we are using 3 config readers,
if the first config reader returns

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

and the second returns

    item2: content9
    item3:
        subitem2: subcontent8
        subitem3:
            subsubitem1:
                subsubcontent7
        subitem4:
            subsubitem5: subsubcontent5
    item4: content4

then the final config is

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

The default B<ConfigReader> is C<Dancer2::ConfigReader::Config::Any>.

=head2 Configuring the ConfigReaders via DANCER_CONFIG_READERS

You can control which B<ConfigReader>
class or classes to use to create the config
via the C<DANCER_CONFIG_READERS> environment.

    DANCER_CONFIG_READERS='Dancer2::ConfigReader::Config::Any,Dancer2::ConfigReader::CustomConfig'

If you want several, separate them with a comma (",").

=head2 Bootstrapping the ConfigReaders via C<additional_config_readers>

If the key C<additional_config_readers> is found in one in one or more of the configurations provided by the ConfigReaders, it'll be
instantiated and added to the list of configurations to merge. This way you can, for example, create a basic F<config.yml> that is

    additional_config_readers:
        - Dancer2::ConfigReader::SQLite:
            path: /path/to/sqlite.db
            table: config

The default ConfigReader L<Dancer2::ConfigReader::Config::Any> will pick that file and proceed to instantiate C<Dancer2::ConfigReader::SQLite>
with the provided parameters.

C<additional_config_readers> can take one or a list of reader configurations, which can be either the name of the ConfigReader's class, or the
key/value pair of the class name and its constructor's arguments.

=head2 Creating your own custom B<ConfigReader> classes.

Here's an example extending class C<Dancer2::ConfigReader::Config::Any>.

    package Dancer2::ConfigReader::FileExtended;
    use Moo;
    extends 'Dancer2::ConfigReader::Config::Any';
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

Another (more complex) example is in class C<Dancer2::ConfigReader::Config::Any>.

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
