package Dancer2::Logger::Note;
# ABSTRACT: Test::More note() logging engine for Dancer2

use Moo;
use Test::More;

with 'Dancer2::Core::Role::Logger';

sub log {
    my ( $self, $level, $message ) = @_;

    Test::More::note( $self->format_message( $level => $message ) );
}

1;

__END__

=head1 DESCRIPTION

This logging engine uses L<Test::More>'s note() to output as TAP comments.

This is very useful in case you're writing a test and want to have logging
messages as part of your TAP.

"Like C<diag()>, except the message will not be seen when the test is run in a
harness. It will only be visible in the verbose TAP stream." -- Test::More.

=method log

Use Test::More's note() to output the log message.

=cut
