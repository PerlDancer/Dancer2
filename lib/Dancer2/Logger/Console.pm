package Dancer2::Logger::Console;
# ABSTRACT: Console logger

use Moo;

with 'Dancer2::Core::Role::Logger';

sub log {
    my ( $self, $level, $message ) = @_;
    print STDERR $self->format_message( $level => $message );
}

1;

__END__

=head1 DESCRIPTION

This is a logging engine that allows you to print debug messages on the
standard error output.

=head1 CONFIGURATION

The setting C<logger> should be set to C<console> in order to use this logging
engine in a Dancer2 application.

There is no additional setting available with this engine.

=head1 METHODS

=method log

Writes the log message to the console.

=head1 SEE ALSO

L<Dancer2::Core::Role::Logger>
