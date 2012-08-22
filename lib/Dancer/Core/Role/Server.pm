# ABSTRACT: TODO

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

has name => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_name',
);

has host => (
    is => 'rw',
    isa => Str,
    required => 1,
);

has port => (
    is => 'rw',
    isa => Num,
    required => 1,
);

has is_daemon => (
    is => 'rw',
    isa => Bool,
);

has apps => (
    is => 'ro',
    isa => ArrayRef,
    default => sub { [] },
);

has runner => (
    is => 'ro',
    required => 1,
    isa => ObjectOf('Dancer::Core::Runner'),
    weak_ref => 1,
);

# The dispatcher to dispatch an incoming request to the appropriate route
# handler
has dispatcher => (
    is => 'rw',
    isa => ObjectOf('Dancer::Core::Dispatcher'),
    lazy => 1,
    builder => '_build_dispatcher',
);

requires '_build_name';

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
        $self->dispatcher->dispatch($env)->to_psgi;
    };
}

sub register_application {
    my ($self, $app) = @_;
    push @{ $self->apps }, $app;
    $app->server($self);
    $app->server->runner->postponed_hooks({
        %{ $app->server->runner->postponed_hooks },
        %{ $app->postponed_hooks }
    });
}

1;
