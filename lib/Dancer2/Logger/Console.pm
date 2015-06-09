package Dancer2::Logger::Console;
# ABSTRACT: Console logger
$Dancer2::Logger::Console::VERSION = '0.159002';
use Moo;

with 'Dancer2::Core::Role::Logger';

sub log {
    my ( $self, $level, $message ) = @_;
    print STDERR $self->format_message( $level => $message );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Logger::Console - Console logger

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This is a logging engine that allows you to print debug messages on the
standard error output.

=head1 METHODS

=head2 log

Writes the log message to the console.

=head1 CONFIGURATION

The setting C<logger> should be set to C<console> in order to use this logging
engine in a Dancer2 application.

There is no additional setting available with this engine.

=head1 METHODS

=head1 SEE ALSO

L<Dancer2::Core::Role::Logger>

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
