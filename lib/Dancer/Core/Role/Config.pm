package Dancer::Core::Role::Config;
use Moo::Role;

# provide a "config" attribute with automatic population from config files

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

    my $config = {};
    foreach my $file ($self->config_files) {
        my $current = $self->load_config_file($file);
        $config = {%{$config}, %{$current}};
    }

    return $config;
}

1;
