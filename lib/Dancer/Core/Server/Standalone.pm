# ABSTRACT: TODO

package Dancer::Core::Server::Standalone;

use Moo;
use Dancer::Core::Types;
with 'Dancer::Core::Role::Server';

sub _build_name {'Standalone'}

use HTTP::Server::Simple::PSGI;

has backend => (
    is      => 'ro',
    isa     => InstanceOf['HTTP::Server::Simple::PSGI'],
    lazy    => 1,
    builder => '_build_backend',
);

sub _build_backend {
    my $self    = shift;
    my $backend = HTTP::Server::Simple::PSGI->new( $self->port );

    $backend->host( $self->host     );
    $backend->app(  $self->psgi_app );

    return $backend;
}

sub start {
    my $self = shift;

    $self->is_daemon
        ? $self->backend->background()
        : $self->backend->run();
}

1;

__END__

=head1 DESCRIPTION

This is a server implementation for a stand-alone server. It contains all the
code to start an L<HTTP::Server::Simple::PSGI> server and handle the requests.

=head1 ATTRIBUTES

=head2 backend

A L<HTTP::Server::Simple::PSGI> server.

=head1 METHODS

=head2 name

The server's name: B<Standalone>.

=head2 start

Starts the server.

