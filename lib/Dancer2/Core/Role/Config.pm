package Dancer2::Core::Role::Config;

# ABSTRACT: Config role for Dancer2 core objects

use Moo::Role;

use Dancer2::Core::Factory;
use File::Spec;
use Config::Any;
use Dancer2::Core::Types;
use Dancer2::FileUtils qw/dirname path/;
use Hash::Merge::Simple;
use Carp 'croak', 'carp';

has location => (
    is       => 'rw',
    required => 1,
    lazy     => 1,
    default  => sub { File::Spec->rel2abs('.') },
    coerce   => sub {
        my ($value) = @_;
        return File::Spec->rel2abs($value)
          if !File::Spec->file_name_is_absolute($value);
        return $value;
    },
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

# TODO: make readonly and add method rebuild_config?
has config => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config',
);

has engines => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_engines',
);

has environment => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_environment',
);

sub _build_environment {
    $ENV{DANCER_ENVIRONMENT} || $ENV{PLACK_ENV} || 'development';
}

has _engines_triggers => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_engines_triggers',
);

has _config_triggers => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config_triggers',
);

has supported_engines => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    default => sub {[qw/logger serializer session template/]},
);

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

has config_files => (
    is      => 'rw',
    lazy    => 1,
    isa     => ArrayRef,
    builder => '_build_config_files',
);

sub _build_config_files {
    my ($self) = @_;
    my $location = $self->config_location;

    # an undef location means no config files for the caller
    return [] unless defined $location;

    my $running_env = $self->environment;
    my @exts        = Config::Any->extensions;
    my @files;

    foreach my $ext (@exts) {
        foreach my $file ( [ $location, "config.$ext" ],
            [ $self->environments_location, "$running_env.$ext" ] )
        {
            my $path = path( @{$file} );
            next if !-r $path;

            push @files, $path;
        }
    }

    return [ sort @files ];
}

sub load_config_file {
    my ( $self, $file ) = @_;
    my $config;

    eval {
        my @files = ($file);
        my $tmpconfig =
          Config::Any->load_files( { files => \@files, use_ext => 1 } )->[0];
        ( $file, $config ) = %{$tmpconfig};
    };
    if ( my $err = $@ || ( !$config ) ) {
        croak "Unable to parse the configuration file: $file: $@";
    }

    # TODO handle mergeable entries
    return $config;
}

sub get_postponed_hooks {
    my ($self) = @_;
    return $self->postponed_hooks;
    # XXX FIXME
    # return ( ref($self) eq 'Dancer2::Core::App' )
    #   ? (
    #     ( defined $self->server )
    #     ? $self->server->runner->postponed_hooks
    #     : {}
    #   )
    #   : $self->can('postponed_hooks') ? $self->postponed_hooks
    #   :                                 {};
}

# private

sub _build_config {
    my ($self) = @_;
    my $location = $self->config_location;

    my $default = {};
    $default = $self->default_config
      if $self->can('default_config');

    my $config = Hash::Merge::Simple->merge(
        $default,
        map { $self->load_config_file($_) } @{ $self->config_files }
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

my $_normalizers = {
    charset => sub {
        my ($charset) = @_;
        return $charset if !length( $charset || '' );

        require Encode;
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

sub _build_engines_triggers {
    my $self = shift;

    my $triggers = {};

    foreach my $engine (@{$self->supported_engines}) {
        $triggers->{$engine} = sub {
            my ($self, $value, $config) = @_;

            return $value if ref($value);

            my $method = "_build_engine_$engine";
            my $e = $self->$method($value, $config);
            $self->engines->{$engine} = $e;
            return $e;
        };
    }

    return $triggers;
}

sub _build_config_triggers {
    my $self = shift;

    # TODO route_cache
    return {
        import_warnings => sub {
            my ( $self, $value ) = @_;
            $^W = $value ? 1 : 0;
        },
        traces => sub {
            my ( $self, $traces ) = @_;
            require Carp;
            $Carp::Verbose = $traces ? 1 : 0;
        },
        views => sub {
            my ( $self, $value, $config ) = @_;
            $self->engine('template')->views($value);
        },
        layout => sub {
            my ( $self, $value, $config ) = @_;
            $self->engine('template')->layout($value);
        },
    };
}

sub _compile_config_entry {
    my ( $self, $name, $value, $config ) = @_;

    my $trigger;

    if (grep {$name eq $_} @{$self->supported_engines}) {
        $trigger = $self->_engines_triggers->{$name};
    }else{
        $trigger = $self->_config_triggers->{$name};
    }

    return $value unless defined $trigger;

    return $trigger->( $self, $value, $config );
}

sub _get_config_for_engine {
    my ( $self, $engine, $name, $config ) = @_;

    my $default_config = {
        environment => $self->environment,
        location    => $self->config_location,
    };
    return $default_config unless defined $config->{engines};

    if ( !defined $config->{engines}{$engine} ) {
        return $default_config;
    }

    my $engine_config = {};

    # XXX we need to move the camilize function out from Core::Factory
    # - Franck, 2013/08/03
    for my $config_key ($name, Dancer2::Core::Factory::_camelize($name)) {
        $engine_config = $config->{engines}{$engine}{$config_key}
            if defined $config->{engines}->{$engine}{$config_key};
    }
    return { %{$default_config}, %{$engine_config}, } || $default_config;
}

sub _build_engines {
    my $self = shift;
    return {
        logger     => $self->_build_engine_logger(),
        session    => $self->_build_engine_session(),
        template   => $self->_build_engine_template(),
        serializer => $self->_build_engine_serializer(),
    };
}

sub _build_engine_logger {
    my ($self, $value, $config) = @_;

    $config = $self->config     if !defined $config;
    $value  = $config->{logger} if !defined $value;

    return $value if ref($value);

    # XXX This is needed for the tests that create an app without
    # a runner.
    $value = 'console' if !defined $value;

    my $engine_options =
        $self->_get_config_for_engine( logger => $value, $config );

    return Dancer2::Core::Factory->create(
        logger => $value,
        %{$engine_options},
        app_name        => $self->name,
        postponed_hooks => $self->get_postponed_hooks
    );
}

sub _build_engine_session {
    my ($self, $value, $config)  = @_;

    $config = $self->config        if !defined $config;
    $value  = $config->{'session'} if !defined $value;

    $value = 'simple' if !defined $value;
    return $value     if ref($value);

    my $engine_options =
          $self->_get_config_for_engine( session => $value, $config );

    return Dancer2::Core::Factory->create(
        session => $value,
        %{$engine_options},
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _build_engine_template {
    my ($self, $value, $config)  = @_;

    $config = $self->config         if !defined $config;
    $value  = $config->{'template'} if !defined $value;

    return undef  if !defined $value;
    return $value if ref($value);

    my $engine_options =
          $self->_get_config_for_engine( template => $value, $config );

    my $engine_attrs = { config => $engine_options };
    $engine_attrs->{layout} ||= $config->{layout};
    $engine_attrs->{views}  ||= $config->{views}
        || path( $self->location, 'views' );

    return Dancer2::Core::Factory->create(
        template => $value,
        %{$engine_attrs},
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _build_engine_serializer {
    my ($self, $value, $config) = @_;

    $config = $self->config         if !defined $config;
    $value  = $config->{serializer} if !defined $value;

    return undef  if !defined $value;
    return $value if ref($value);

    my $engine_options =
        $self->_get_config_for_engine( serializer => $value, $config );

    return Dancer2::Core::Factory->create(
        serializer      => $value,
        config          => $engine_options,
        postponed_hooks => $self->get_postponed_hooks,
    );
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

=attr engines

Returns all the engines.

=attr environments

Returns the name of the environment.

=attr config_files

List of all the configuration files.

=attr supported_engines

The list of engines supported by Dancer.

=over 4

=item logger

=item serializer

=item session

=item template

=back

=head1 METHODS

=head2 settings

Alias for config. Equivalent to <<$object->config>>.

=head2 setting

Get or set an element from the configuration.

=head2 has_setting

Verifies that a key exists in the configuration.

=head2 load_config_file

Load the configuration files.

=head2 get_postponed_hooks
