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

requires 'name';

has apps => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

sub register_application {
    my ($self, $app) = @_;
    push @{ $self->apps }, $app;
}

has host => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Str(@_) },
);

has port => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Num(@_) },
);

has is_daemon => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Bool(@_) },
);

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
