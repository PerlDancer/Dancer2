package Dancer::Core::Role::Config;
# ABSTRACT: Config role for Dancer core objects

use Moo::Role;

=head1 DESCRIPTION

Provides a C<config> attribute that feeds itself by finding and parsing
configuration files.

Also provides a C<setting()> method which is supposed to be used by externals to
read/write config entries.

=cut

use Dancer::Factory::Engine;
use File::Spec;
use Config::Any;
use Dancer::Core::Types;
use Dancer::FileUtils qw/dirname path/;
use Carp 'croak', 'carp';

=method config_location

Gets the location from the configuration. Same as C<< $object->location >>.

=cut

has config_location => (
    is      => 'ro',
    isa     => ReadableFilePath,
    lazy    => 1,
    builder => '_build_config_location',
);

has config => (
    is => 'rw',
    isa => HashRef,
    lazy => 1,
    builder => '_build_config',
);

has environment => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_environment',
);

sub settings { shift->config }

sub setting {
    my $self = shift;
    my @args = @_;

    return (scalar @args == 1)
        ? $self->settings->{$args[0]}
        : $self->_set_config_entries(@args);
}

sub has_setting {
    my ($self, $name) = @_;
    return exists $self->config->{$name};
}

has config_files => (
    is => 'rw',
    lazy => 1,
    isa => ArrayRef,
    builder => '_build_config_files',
);

sub _build_config_files {
    my ($self) = @_;
    my $location = $self->config_location;

    # an undef location means no config files for the caller
    return [] unless defined $location;

    my $running_env = $self->environment;
    my @exts = Config::Any->extensions;
    my @files;

    foreach my $ext( @exts ) {
        foreach my $file (
            ["config.$ext"],
            ['environments', "$running_env.$ext"]) {

            my $path = path($location, @{$file});
            next if ! -r $path;

            push @files, $path;
        }
    }

    return [ sort @files ];
}

sub load_config_file {
    my ($self, $file) = @_;
    my $config;

    eval {
        my @files = ( $file );
        my $tmpconfig = Config::Any->load_files({ files => \@files, use_ext => 1 })->[0];
        ( $file, $config ) = %{ $tmpconfig };
    };
    if ( my $err = $@ || (!$config) ) {
        croak "Unable to parse the configuration file: $file: $@";
    }

    # TODO handle mergeable entries
    return $config;
}

sub get_postponed_hooks {
    my ($self) = @_;
    return (ref($self) eq 'Dancer::Core::App')
        ? (
            (defined $self->server)
            ? $self->server->runner->postponed_hooks
            : {}
        )
        : $self->can('postponed_hooks') ? $self->postponed_hooks : {} ;
}

# private

sub _build_config {
    my ($self) = @_;
    my $location = $self->config_location;

    my $config = {};
    $config = $self->default_config
        if $self->can('default_config');

    foreach my $file (@{ $self->config_files }) {
        my $current = $self->load_config_file($file);
        $config = {%{$config}, %{$current}};
    }

    $config = $self->_normalize_config($config);
    return  $self->_compile_config($config);
}

sub _set_config_entries {
    my ($self, @args) = @_;
    my $no=scalar @args;    
    while (@args) {
        $self->_set_config_entry(shift(@args), shift(@args));
    }
    return $no;
}

sub _set_config_entry {
    my ($self, $name, $value) = @_;

    $value = $self->_normalize_config_entry($name, $value);
    $value = $self->_compile_config_entry($name, $value, $self->config);
    $self->config->{$name} = $value;
}

sub _normalize_config {
    my ($self, $config) = @_;

    foreach my $key (keys %{$config}) {
        my $value = $config->{$key};
        $config->{$key} = $self->_normalize_config_entry($key, $value);
    }
    return $config;
}

sub _compile_config {
    my ($self, $config) = @_;

    foreach my $key (keys %{$config}) {
        my $value = $config->{$key};
        $config->{$key} = $self->_compile_config_entry($key, $value, $config);
    }
    return $config;
}

my $_normalizers = {
    charset => sub {
        my ($charset) = @_;
        return $charset if !length($charset || '');

        require Encode;
        my $encoding = Encode::find_encoding($charset);
        croak "Charset defined in configuration is wrong : couldn't identify '$charset'"
            unless defined $encoding;
        my $name = $encoding->name;

        # Perl makes a distinction between the usual perl utf8, and the strict
        # utf8 charset. But we don't want to make this distinction
        $name = 'utf-8' if $name eq 'utf-8-strict';
        return $name;
    },
};

sub _normalize_config_entry {
    my ($self, $name, $value) = @_;
    $value = $_normalizers->{$name}->($value)
        if exists $_normalizers->{$name};
    return $value;
}

my $_setters = {
    logger => sub {
        my ($self, $value, $config) = @_;

        return $value if ref($value);
        my $engine_options = $self->_get_config_for_engine(logger => $value, $config);

        # keep compatibility with old 'log' keyword to define log level.
        if (!exists($engine_options->{log_level}) and exists($config->{log})) {
            $engine_options->{log_level} = $config->{log};
        }
        return Dancer::Factory::Engine->create(
            logger => $value,
            %{$engine_options},
            app_name => $self->name,
            postponed_hooks => $self->get_postponed_hooks
        );
    },

    session => sub {
        my ($self, $value, $config) = @_;
        return $value if ref($value);

        my $engine_options =
          $self->_get_config_for_engine(session => $value, $config);

        return Dancer::Factory::Engine->create(
            session_factory => $value,
            %{$engine_options},
            postponed_hooks => $self->get_postponed_hooks,
        );
    },

    template => sub {
        my ($self, $value, $config) = @_;
        return $value if ref($value);

        my $engine_options = $self->_get_config_for_engine(template => $value, $config);
        my $engine_attrs = {config => $engine_options};
        $engine_attrs->{layout} ||= $config->{layout};
        $engine_attrs->{views}  ||= path( $self->config_location, 'views' );

        return Dancer::Factory::Engine->create(
            template => $value,
            %{$engine_attrs},
            postponed_hooks => $self->get_postponed_hooks,
        );
    },
#    route_cache => sub {
#        my ($setting, $value) = @_;
#        require Dancer::Route::Cache;
#        Dancer::Route::Cache->reset();
#    },
    serializer => sub {
        my ($self, $value, $config) = @_;

        my $engine_options = $self->_get_config_for_engine(
            serializer => $value, $config);

        return Dancer::Factory::Engine->create(
            serializer => $value,
            config => $engine_options,
            postponed_hooks => $self->get_postponed_hooks,
        );
    },
    import_warnings => sub {
        my ($self, $value) = @_;
        $^W = $value ? 1 : 0;
    },
    traces => sub {
        my ($self, $traces) = @_;
        require Carp;
        $Carp::Verbose = $traces ? 1 : 0;
    },
};
$_setters->{log_path} = $_setters->{log_file};

sub _compile_config_entry {
    my ($self, $name, $value, $config) = @_;

    my $trigger = $_setters->{$name};
    return $value unless defined $trigger;

    return $trigger->($self, $value, $config);
}

sub _get_config_for_engine {
    my ($self, $engine, $name, $config) = @_;

    my $default_config = {
        environment => $self->environment,
        location    => $self->config_location,
    };
    return $default_config unless defined $config->{engines};

    if (! defined $config->{engines}{$engine}) {
        return $default_config;
    }

    my $engine_config = $config->{engines}{$engine}{$name} || {};
    return {
        %{ $default_config },
        %{ $engine_config } ,
    } || $default_config;
}

1;
