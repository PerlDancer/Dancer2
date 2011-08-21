package Dancer::Core::Server::Standalone;

use Moo;
with 'Dancer::Core::Role::Server';

sub name { 'Standalone' }

use HTTP::Server::Simple::PSGI;

has backend => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('HTTP::Server::Simple::PSGI' => @_) },
);

sub BUILD {
    my ($self) = @_;

    $self->backend(HTTP::Server::Simple::PSGI->new($self->port));
    $self->backend->host($self->host);
    $self->backend->app($self->psgi_app);
}

sub start {
    my $self = shift;

    $self->is_daemon
        ? $self->backend->background() 
        : $self->backend->run();
}

1;
