package Dancer2::Logger::Capture::Trap;
# ABSTRACT: a place to store captured Dancer2 logs

use Moo;
use Dancer2::Core::Types;

has storage => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

sub store {
    my ( $self, $level, $message, $fmt_string ) = @_;
    push @{ $self->storage }, {
        level     => $level,
        message   => $message,
        formatted => $fmt_string,
    };
}

sub read {
    my $self = shift;

    my $logs = $self->storage;
    $self->storage( [] );
    return $logs;
}

1;
__END__

=head1 SYNOPSIS

    my $trap = Dancer2::Logger::Capture::Trap->new;
    $trap->store( $level, $message );
    my $logs = $trap->read;

=head1 DESCRIPTION

This is a place to store and retrieve capture Dancer2 logs used by
L<Dancer2::Logger::Capture>.

=head2 Methods

=head3 new

=head3 store

    $trap->store($level, $message);

Stores a log $message and its $level.

=head3 read

    my $logs = $trap->read;

Returns the logs stored as an array ref and clears the storage.

For example...

    [{ level => "warning", message => "Danger! Warning! Dancer2!" },
     { level => "error",   message => "You fail forever" }
    ];

=head1 SEE ALSO

L<Dancer2::Logger::Capture>

=cut
