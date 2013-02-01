# ABSTRACT: TODO

package Dancer::Logger::v2::Console;
use Moo;
with 'Dancer::Core::Role::Logger';

sub log {
    my ($self, $level, $message) = @_;
    print STDERR $self->format_message($level => $message);
}

1;
