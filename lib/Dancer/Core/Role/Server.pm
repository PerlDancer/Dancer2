package Dancer::Core::Role::Server;
use Moo::Role;

use Carp 'croak';
use File::Spec;

use Dancer::Moo::Types;

use Dancer::Core::App;
use Dancer::Core::Dispatcher;
use Dancer::Core::Response;
use Dancer::Core::Request;
use Dancer::Core::Context;

# we have a config registry
with 'Dancer::Core::Role::Config';

has apps => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

sub register_application {
    my ($self, $app) = @_;
    push @{ $self->apps }, $app;
}

# these ones are not settings, despite what did Dancer1
# they are server options, and they cant be changed with config files (and
# never were).
# They're supposed to be filled via environement or command-line options.
# Actually, they must be set before the server starts, that's why we dont want
# them in regular settings.
has host => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Str(@_) },
    default => sub { $ENV{DANCER_SERVER} || '0.0.0.0' },
);

has port => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Num(@_) },
    default => sub { $ENV{DANCER_PORT} || 3000 },
);

has is_daemon => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Bool(@_) },
    default => sub { $ENV{DANCER_DAEMON} || 0 },
);

has environment => (
    is => 'ro',
    isa => sub { Str(@_) },
    default => sub { 
        $ENV{DANCER_ENVIRONMENT} || 
        $ENV{PLACK_ENV} || 
        'development' 
    },
);
# our Config role needs a get_environment mehtod and a default_config hash
sub get_environment { $_[0]->environment }
sub default_config {
    {
        apphandler   => ($ENV{DANCER_APPHANDLER} || 'Standalone'),
        content_type => ($ENV{DANCER_CONTENT_TYPE} || 'text/html'),
        charset      => ($ENV{DANCER_CHARSET} || ''),
        warnings     => ($ENV{DANCER_WARNINGS} || 0),
        traces       => ($ENV{DANCER_TRACES} || 0),
        logger       => ($ENV{DANCER_LOGGER} || 'file'),
        import_warnings => 1,
    };
}

# the absolute path to the directory where the server started
has location => (
    is => 'ro',
    isa => sub { Str(@_) },
    required => 1,
    # make sure the path given is always absolute
    coerce => sub {
        my ($value) = @_;
        return File::Spec->rel2abs($value) 
            if !File::Spec->file_name_is_absolute($value);
        return $value;
    },
);
sub config_location { $_[0]->location }

# The dispatcher to dispatch an incoming request to the appropriate route
# handler
has dispatcher => (
    is => 'rw',
    isa => sub { ObjectOf('Dancer::Core::Dispatcher', @_) },
    lazy => 1,
    builder => '_build_dispatcher',
);

sub _build_dispatcher {
    my ($self) = @_;
    my $d = Dancer::Core::Dispatcher->new();
    $d->apps( $self->apps );
    return $d;
}

# our PSGI application
sub psgi_app {
    my ($self) = @_;
    sub {
        my ($env) = @_;
        $self->dispatcher->dispatch($env);
    };
}

1;
