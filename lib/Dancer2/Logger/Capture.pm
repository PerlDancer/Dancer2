package Dancer2::Logger::Capture;
# ABSTRACT: Capture dancer logs

use Moo;
use Dancer2::Logger::Capture::Trap;

with 'Dancer2::Core::Role::Logger';

=head1 SYNOPSIS

The basics:

    set logger => "capture";

    my $trap = dancer_app->engine('logger')->trapper;
    my $logs = $trap->read;

A worked-out real-world example:

    use Test::More tests => 2;
    use Dancer2;

    set logger => 'capture';

    warning "Danger!  Warning!";
    debug   "I like pie.";

    my $trap = dancer_app->engine('logger')->trapper;

    is_deeply $trap->read, [
        { level => "warning", message => "Danger!  Warning!" },
        { level => "debug",   message => "I like pie.", }
    ];

    # each call to read cleans the trap
    is_deeply $trap->read, [];


=head1 DESCRIPTION

This is a logger class for L<Dancer2> which captures all logs to an object.

It's primary purpose is for testing.

=method trap

Returns the L<Dancer2::Logger::Capture::Trap> object used to capture
and read logs.

=cut

has trapper => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_trapper',
);

sub _build_trapper { Dancer2::Logger::Capture::Trap->new }

sub log {
    my ( $self, $level, $message ) = @_;

    $self->trapper->store( $level => $message );
    return;
}

1;

=head1 SEE ALSO

L<Dancer2::Core::Role::Logger>, L<Dancer2::Logger::Capture::Trap>

=cut
