# ABSTRACT: Basic standalone HTTP server for Dancer2

package Dancer2::Core::Server::Standalone;

use Moo;
use Dancer2::Core::Types;
with 'Dancer2::Core::Role::Server';
use parent 'HTTP::Server::Simple::PSGI';

=head1 DESCRIPTION

This is a server implementation for a stand-alone server. It contains all the
code to start an L<HTTP::Server::Simple::PSGI> server and handle the requests.

This class consumes the role L<Dancer2::Core::Server::Standalone>.

=method name

The server's name: B<Standalone>.

=cut

sub _build_name {'Standalone'}

=attr backend

A L<HTTP::Server::Simple::PSGI> server.

=cut

has backend => (
    is      => 'ro',
    isa     => InstanceOf ['HTTP::Server::Simple::PSGI'],
    lazy    => 1,
    builder => '_build_backend',
);

sub _build_backend {
    my $self = shift;
    $self->app( $self->psgi_app );
    return $self;
}

=method start

Starts the server.

=cut

sub start {
    my $self = shift;

    $self->is_daemon
      ? $self->backend->background()
      : $self->backend->run();

}

sub print_banner {
    my $self = shift;
    my $pid  = $$;      #Todo:how to get background pid?

    # we only print the info if we need to
    Dancer2->runner->config->{'startup_info'} or return;

    # bare minimum
    print STDERR ">> Dancer2 v$Dancer2::VERSION server $pid listening "
      . 'on http://'
      . $self->host . ':'
      . $self->port . "\n";

    # all loaded plugins
    foreach my $module ( grep { $_ =~ m{^Dancer2/Plugin/} } keys %INC ) {
        $module =~ s{/}{::}g;     # change / to ::
        $module =~ s{\.pm$}{};    # remove .pm at the end
        my $version = $module->VERSION;

        defined $version or $version = 'no version number defined';
        print STDERR ">> $module ($version)\n";
    }

}
1;
