package Dancer::Core::Role::Config;
use Moo::Role;

# provide a "config" attribute that feeds itself by finding and parsing
# configuration files.
# also provides a setting() method which is supposed to be used by externals to
# read/write config entries.

use Dancer::Moo::Types;
use Dancer::FileUtils qw/dirname path/;
use Carp 'croak';

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
        : $self->_set_config_entry(@args);
}

sub config_files {
    my ($self) = @_;
    my @files;

    my $location = $self->config_location;
    my $running_env = $self->get_environment;

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
    
    my $_default_config = {
        apphandler   => ($ENV{DANCER_APPHANDLER} || 'Standalone'),
        content_type => ($ENV{DANCER_CONTENT_TYPE} || 'text/html'),
        charset      => ($ENV{DANCER_CHARSET} || ''),
        warnings     => ($ENV{DANCER_WARNINGS} || 0),
        traces       => ($ENV{DANCER_TRACES} || 0),
        logger       => ($ENV{DANCER_LOGGER} || 'file'),
        import_warnings => 1,
    };

    my $config = $_default_config;
    foreach my $file ($self->config_files) {
        my $current = $self->load_config_file($file);
        $config = {%{$config}, %{$current}};
    }

    $config = $self->_normalize_config($config);
    return  $self->_compile_config($config);
}

sub _set_config_entry {
    my ($self, $name, $value) = @_;
    $value = $self->_normalize_config_entry($name, $value);
    $value = $self->_compile_config_entry($name, $value);
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
        $config->{$key} = $self->_compile_config_entry($key, $value);
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
#    logger => sub {
#        my ($setting, $value) = @_;
#        Dancer::Logger->init($value, settings());
#    },
#    log_file => sub {
#        Dancer::Logger->init(setting("logger"), setting());
#    },
#    session => sub {
#        my ($setting, $value) = @_;
#        Dancer::Session->init($value, settings());
#    },
#    template => sub {
#        my ($setting, $value) = @_;
#        Dancer::Template->init($value, settings());
#    },
#    route_cache => sub {
#        my ($setting, $value) = @_;
#        require Dancer::Route::Cache;
#        Dancer::Route::Cache->reset();
#    },
#    serializer => sub {
#        my ($setting, $value) = @_;
#        require Dancer::Serializer;
#        Dancer::Serializer->init($value);
#    },
#    import_warnings => sub {
#        my ($setting, $value) = @_;
#        $^W = $value ? 1 : 0;
#    },
#    auto_page => sub {
#        my ($setting, $auto_page) = @_;
#        if ($auto_page) {
#            require Dancer::App;
#            Dancer::App->current->registry->universal_add(
#                'get', '/:page',
#                sub {
#                    my $params = Dancer::SharedData->request->params;
#                    if  (-f Dancer::engine('template')->view($params->{page})) {
#                        return Dancer::template($params->{'page'});
#                    } else {
#                        return Dancer::pass();
#                    }
#                }
#            );
#        }
#    },
    traces => sub {
        my ($traces) = @_;
        require Carp;
        $Carp::Verbose = $traces ? 1 : 0;
    },
};
$_setters->{log_path} = $_setters->{log_file};

sub _compile_config_entry {
    my ($self, $name, $value) = @_;

    my $trigger = $_setters->{$name};
    return $value unless defined $trigger;

    return $trigger->($value);
}

1;
