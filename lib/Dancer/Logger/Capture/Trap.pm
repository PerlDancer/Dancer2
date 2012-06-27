# ABSTRACT: a place to store captured Dancer logs

package Dancer::Logger::Capture::Trap;
use Moo;
use Dancer::Moo::Types;

has _storage => (
    is => 'rw',
    isa => sub { ArrayRef(@_) },
    default => sub { [] },
);

sub store {
    my($self, $level, $message) = @_;
    push @{$self->_storage}, { level => $level, message => $message };
}

sub read {
    my $self = shift;

    my $logs = $self->_storage;
    $self->_storage([]);
    return $logs;
}

1;
__END__

=head1 SYNOPSIS

    my $trap = Dancer::Logger::Capture::Trap->new;
    $trap->store( $level, $message );
    my $logs = $trap->read;

=head1 DESCRIPTION

This is a place to store and retrieve capture Dancer logs used by
L<Dancer::Logger::Capture>.

=head2 Methods

=head3 new

=head3 store

    $trap->store($level, $message);

Stores a log $message and its $level.

=head3 read

    my $logs = $trap->read;

Returns the logs stored as an array ref and clears the storage.

For example...

    [{ level => "warning", message => "Danger! Warning! Dancer!" },
     { level => "error",   message => "You fail forever" }
    ];

=head1 SEE ALSO

L<Dancer::Logger::Capture>

=cut
