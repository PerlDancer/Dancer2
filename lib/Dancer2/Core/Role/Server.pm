# ABSTRACT: Role for Server classes

package Dancer2::Core::Role::Server;
use Moo::Role;

use Carp 'croak';
use File::Spec;

use Dancer2::Core::Types;
use Dancer2::Core::App;
use Dancer2::Core::Dispatcher;
use Dancer2::Core::Response;
use Dancer2::Core::Request;
use Dancer2::Core::Context;

=head1 DESCRIPTION

This role defines what servers need to implement and provide some helpful
attributes and methods for server implementations.

This role requires implementations that consume it to provide a C<name>
subroutine.

=cut

has name => (
    is      => 'ro',
    lazy    => 1,
    builder => 1,
);

=attr host

Hostname to which the server will bind.

B<Required>.

=cut

has host => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

=attr port

Port number to which the server will bind.

B<Required>.

=cut

has port => (
    is       => 'rw',
    isa      => Num,
    required => 1,
);

=attr is_daemon

Boolean for whether the server should daemonize.

=cut

has is_daemon => (
    is  => 'rw',
    isa => Bool,
);

=attr apps

An arrayref to hold Dancer2 applications.

=cut

has apps => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

has runner => (
    is       => 'ro',
    required => 1,
    isa      => InstanceOf ['Dancer2::Core::Runner'],
    weak_ref => 1,
);

=attr dispatcher

A read/write attribute which holds the L<Dancer2::Core::Dispatcher> object, to 
dispatch an incoming request to the appropriate route.

It has a lazy builder that creates a new dispatcher with the server's apps.

=cut

has dispatcher => (
    is      => 'rw',
    isa     => InstanceOf ['Dancer2::Core::Dispatcher'],
    lazy    => 1,
    builder => '_build_dispatcher',
);

requires '_build_name';

sub _build_dispatcher {
    my ($self) = @_;
    my $d = Dancer2::Core::Dispatcher->new();
    $d->apps( $self->apps );
    return $d;
}

=method psgi_app

Returns a code reference of a proper PSGI reply to a dispatched request.

It dispatches the request using the dispatcher (and provides the environment
variables) and then calls C<to_psgi> and returns that reply wrapped in a code
reference.

Please review L<PSGI> for more details on the protocol and how it works.

=cut

# our PSGI application
sub psgi_app {
    my ($self) = @_;
    sub {
        my ($env) = @_;
        my $app;

        eval { $app = $self->dispatcher->dispatch($env)->to_psgi; };

        if ($@) {
            return [
                500,
                [ 'Content-Type' => 'text/plain' ],
                ["Internal Server Error\n\n$@"],
            ];
        }
        return $app;
    };
}

=method register_application

Adds another application to the C<apps> attribute (see above).

=cut

sub register_application {
    my ( $self, $app ) = @_;
    push @{ $self->apps }, $app;
    $app->server($self);
    $app->server->runner->postponed_hooks(
        {   %{ $app->server->runner->postponed_hooks },
            %{ $app->postponed_hooks }
        }
    );
}

1;
