# ABSTRACT: in-memory session backend for Dancer

package Dancer::Session::Simple;
use Moo;
use Dancer::Core::Types;
use Carp;

with 'Dancer::Core::Role::Session';
my %sessions;

=head1 DESCRIPTION

This module implements a very simple session backend, holding all session data
in memory.  This means that sessions are volatile, and no longer exist when the
process exits.  This module is likely to be most useful for testing purposes.


=head1 CONFIGURATION

The setting B<session> should be set to C<Simple> in order to use this session
engine in a Dancer application.

=cut

# create a new session and return the newborn object
# representing that session
sub create { goto &new }

use Data::Dumper;

# Return the session object corresponding to the given id
sub retrieve {
    my ($self, $id) = @_;
    return $sessions{$id};
}


sub destroy {
    my ($self) = @_;
    undef $sessions{$self->id};
}

sub flush {
    my $self = shift;
    $sessions{$self->id} = $self;
    return $self;
}

1;

=head1 SEE ALSO

See L<Dancer::Session> for details about session usage in route handlers.

=cut
