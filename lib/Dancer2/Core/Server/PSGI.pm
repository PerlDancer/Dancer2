# ABSTRACT: Dummy class for passing the PSGI app to a PSGI server

package Dancer2::Core::Server::PSGI;
use Moo;
use Carp;
use Plack::Request;

with 'Dancer2::Core::Role::Server';

=head1 DESCRIPTION

When used as a server, this class just return the PSGI application.

=method name

The server's name: B<PSGI>.

=method start

Return the PSGI application

=cut

sub start {
    my ($self) = @_;
    $self->psgi_app;
}

sub _build_name {'PSGI'}

1;
