# ABSTRACT: TODO

package Dancer::Core::Server::Standalone;

use Moo;
with 'Dancer::Core::Role::Server';

sub name { 'Standalone' }

use HTTP::Server::Simple::PSGI;

has backend => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('HTTP::Server::Simple::PSGI' => @_) },
);

sub start {
    my $self = shift;

    $self->backend(HTTP::Server::Simple::PSGI->new($self->port));
    $self->backend->host($self->host);
    $self->backend->app($self->psgi_app);

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

