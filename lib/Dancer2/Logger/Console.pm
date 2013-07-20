# ABSTRACT: Console logger

package Dancer2::Logger::Console;
use Moo;
with 'Dancer2::Core::Role::Logger';

sub log {
    my ( $self, $level, $message ) = @_;
    print STDERR $self->format_message( $level => $message );
}

1;
