package Dancer2::Session::Simple;
# ABSTRACT: in-memory session backend for Dancer2

use Moo;
use Dancer2::Core::Types;
use Carp;

with 'Dancer2::Core::Role::SessionFactory';

# The singleton that contains all the session objects created
my $SESSIONS = {};

sub _sessions {
    my ($self) = @_;
    return [ keys %{$SESSIONS} ];
}

sub _retrieve {
    my ( $class, $id ) = @_;
    my $s = $SESSIONS->{$id};

    croak "Invalid session ID: $id"
      if !defined $s;

    return $s;
}

sub _destroy {
    my ( $class, $id ) = @_;
    delete $SESSIONS->{$id};
}

sub _flush {
    my ( $class, $id, $data ) = @_;
    $SESSIONS->{$id} = $data;
}

1;

__END__

=head1 DESCRIPTION

This module implements a very simple session backend, holding all session data
in memory.  This means that sessions are volatile, and no longer exist when the
process exits.  This module is likely to be most useful for testing purposes.

=head1 DISCLAIMER

This session factory should not be used in production and is only for
single-process application workers. As the sessions objects are stored
in-memory, they cannot be shared among multiple workers.

=head1 CONFIGURATION

The setting B<session> should be set to C<Simple> in order to use this session
engine in a Dancer2 application.

=head1 SEE ALSO

See L<Dancer2::Core::Session> for details about session usage in route handlers.

=cut
