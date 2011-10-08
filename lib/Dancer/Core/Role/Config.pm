package Dancer::Core::Role::Config;
use Moo::Role;

# provide a "config" attribute that feeds itself by finding and parsing
# configuration files.
# also provides a setting() method which is supposed to be used by externals to
# read/write config entries.

use Dancer::Factory::Engine;
use Dancer::Moo::Types;
use Dancer::FileUtils qw/dirname path/;
use Carp 'croak', 'carp';

requires 'config_location';
requires 'get_environment';

has config => (
    is => 'rw',
    isa => sub { HashRef(@_) },
    lazy => 1,
    builder => '_build_config',
);

sub setting {
    my $self = shift;
    my @args = @_;

    return (scalar @args == 1)
        ? $self->config->{$args[0]}
        : $self->_set_config_entries(@args);
}

sub has_setting {
    my ($self, $name) = @_;
    return exists $self->config->{$name};
}

sub config_files {
    my ($self) = @_;
    my $location = $self->config_location;

    # an undef location means no config files for the caller
    return unless defined $location;

    my $running_env = $self->get_environment;
    my @files;
    foreach my $file (
        ['config.yml'], 
        ['environments', "$running_env.yml"]) {
        my $path = path($location, @{$file});
        next if ! -r $path;
        push @files, $path;
    }

    return @files;
}

sub load_config_file {
    my ($self, $file) = @_;
    my $config;

    require YAML;
    eval { $config = YAML::LoadFile($file) };
    if (my $err = $@ || (!$config)) {
        croak "Unable to parse the configuration file: $file: $@";
    }

    # TODO handle mergeable entries
    return $config;
}

# private

sub _build_config {
    my ($self) = @_;
    my $location = $self->config_location;

    my $config = {};
    $config = $self->default_config 
        if $self->can('default_config');

    foreach my $file ($self->config_files) {
        my $current = $self->load_config_file($file);
        $config = {%{$config}, %{$current}};
    }

    $config = $self->_normalize_config($config);
    return  $self->_compile_config($config);
}

sub _set_config_entries {
    my ($self, @args) = @_;
    while (@args) {
        $self->_set_config_entry(shift(@args), shift(@args));
    }
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
        my ($self, $value) = @_;
        
        return (ref $value)
          ? $value
          : Dancer::Factory::Engine->build(logger => $value);
    },

#    log_file => sub {
#        Dancer::Logger->init(setting("logger"), setting());
#    },
#    session => sub {
#        my ($setting, $value) = @_;
#        Dancer::Session->init($value, settings());
#    },
    template => sub {
        my ($self, $value, $config) = @_;
        return $value if ref($value);
        
        my $engine_options = $self->_get_config_for_engine(template => $value, $config);
        my $engine_attrs = {config => $engine_options};
        $engine_attrs->{layout} ||= $config->{layout};
        $engine_attrs->{views}  ||= path($self->config_location, 'views');

        return Dancer::Factory::Engine->build(template => $value, %{$engine_attrs});
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

        return Dancer::Factory::Engine->build(
            serializer => $value, 
            config => $engine_options);
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

    return {} unless defined $config->{engines};
    
    if (! defined $config->{engines}{$engine}) {
        carp "No config section for engines/$engine "
           . "(unable to find configuration for $name)";
        return {};
    }

    return $config->{engines}{$engine}{$name} || {};
}

1;
