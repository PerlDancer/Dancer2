# ABSTRACT: TODO

package Dancer::Core::Server::Standalone;

use Moo;
with 'Dancer::Core::Role::Server';

sub _build_name { 'Standalone' }

use HTTP::Server::Simple::PSGI;

has backend => (
    is      => 'ro',
    isa     => sub { ObjectOf('HTTP::Server::Simple::PSGI' => @_) },
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
