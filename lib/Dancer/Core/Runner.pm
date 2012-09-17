package Dancer::Core::Runner;
# ABSTRACT: top-layer class that contains what is need to start a dancer app

use Moo;
use Dancer::Moo::Types;
use Dancer::Core::MIME;
use Carp 'croak';

use Dancer::FileUtils;
use File::Basename;
use File::Spec;

with 'Dancer::Core::Role::Config';

# hooks will be applied at the end, when the hookable objects are instanciated,
# not before.
has postponed_hooks => (
    is => 'rw',
    isa => HashRef,
    default => sub { {} },
);

# the path to the caller script that is starting the app
# mandatory, because we use that to determine where the appdir is.
has caller => (
    is => 'ro',
    isa => Str,
    required => 1,
    trigger => sub {
        my ($self, $script) = @_;
        $self->_build_location($script);
    },
);

has server => (
    is      => 'rw',
    isa     => ConsumerOf('Dancer::Core::Role::Server'),
    lazy    => 1,
    builder => '_build_server',
);

# when the runner is created, it has to init the server instance
# according to the configuration
sub _build_server {
    my $self         = shift;
    my $server_name  = $self->config->{apphandler};
    my $server_class = "Dancer::Core::Server::${server_name}";

    eval "use $server_class";
    croak "Unable to load $server_class : $@" if $@;

    return $server_class->new(
        host      => $self->config->{host},
        port      => $self->config->{port},
        is_daemon => $self->config->{is_daemon},
        runner    => $self,
    );
}

has mime_type => (
    is => 'rw',
    isa => ObjectOf("Dancer::Core::MIME"),
    default => sub { Dancer::Core::MIME->new(); },
);

sub _build_environment {
    $ENV{DANCER_ENVIRONMENT} || $ENV{PLACK_ENV} || 'development';
}

# our Config role needs a default_config hash
sub default_config {

    $ENV{PLACK_ENV} and 
        $ENV{DANCER_APPHANDLER} = 'PSGI';

    my ($self) = @_;
    {   apphandler   => ($ENV{DANCER_APPHANDLER}   || 'Standalone'),
        content_type => ($ENV{DANCER_CONTENT_TYPE} || 'text/html'),
        charset      => ($ENV{DANCER_CHARSET}      || ''),
        warnings     => ($ENV{DANCER_WARNINGS}     || 0),
        traces       => ($ENV{DANCER_TRACES}       || 0),
        logger       => ($ENV{DANCER_LOGGER}       || 'console'),
        host         => ($ENV{DANCER_SERVER}       || '0.0.0.0'),
        port         => ($ENV{DANCER_PORT}         || '3000'),
        is_daemon    => ($ENV{DANCER_DAEMON}       || 0),
        appdir       => $self->location,
        import_warnings => 1,
    };
}

# the absolute path to the directory where the server started
has location => (
    is => 'rw',
    isa => Str,
    # make sure the path given is always absolute
    coerce => sub {
        my ($value) = @_;
        return File::Spec->rel2abs($value) 
            if !File::Spec->file_name_is_absolute($value);
        return $value;
    },
);
sub _build_config_location { $_[0]->location }

sub _build_location {
    my ($self, $script) = @_;

    # default to the dir that contains the script...
    my $location = Dancer::FileUtils::dirname($script);

    # ... but we go one step upper if we find out we're in bin or public
    $location = Dancer::FileUtils::path( $location, '..' )
            if File::Basename::basename($location) eq 'bin' 
            || File::Basename::basename($location) eq 'public';

    $self->location($location);
}

sub start {
    my ($self) = @_;
    my $server = $self->server;

    $_->finish for @{ $server->apps };

    # update the server config if needed
    my $port = $self->setting('server_port');
    my $host = $self->setting('server_host');
    my $is_daemon = $self->setting('server_is_daemon');

    $server->port($port) if defined $port;
    $server->host($host) if defined $host;
    $server->is_daemon($is_daemon) if defined $is_daemon;
    $server->start;
}

# Used by 'logger' to get a name from a Runner
sub name { "runner" }

1;
