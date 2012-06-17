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

requires 'name';

has apps => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

has runner => (
    is => 'ro',
    required => 1,
    isa => sub { ObjectOf('Dancer::Core::Runner', @_) },
    weak_ref => 1,
);

sub register_application {
    my ($self, $app) = @_;
    push @{ $self->apps }, $app;
    $app->server($self);
    $app->server->runner->postponed_hooks({
        %{ $app->server->runner->postponed_hooks },
        %{ $app->postponed_hooks }
    });
}

has host => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::Str(@_) },
    required => 1,
);

has port => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::Num(@_) },
    required => 1,
);

has is_daemon => (
    is => 'rw',
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
        $self->dispatcher->dispatch($env)->to_psgi;
    };
}

1;

__END__

=head1 DESCRIPTION

This is a server role that helps define what servers need to implement and
provide some helpful attributes and methods for server implementations.

This role requires implementations that consume it to provide a C<name>
subroutine.

=head1 ATTRIBUTES

=head2 apps

An arrayref to hold Dancer applications.

=head2 host

Hostname to which the server will bind.

B<Required>.

=head2 port

Port number to which the server will bind.

B<Required>.

=head2 is_daemon

Boolean for whether the server should daemonize.

=head2 dispatcher

A read/write attribute which holds the L<Dancer::Core::Dispatcher> object.

It has a lazy builder that creates a new dispatcher with the server's apps.

=head1 METHODS

=head2 register_application

Adds another application to the C<apps> attribute (see above).

=head2 psgi_app

Returns a code reference of a proper PSGI reply to a dispatched request.

It dispatches the request using the dispatcher (and provides the environment
variables) and then calls C<to_psgi> and returns that reply wrapped in a code
reference.

Please review L<PSGI> for more details on the protocol and how it works.

