# ABSTRACT: Test::More diag() logging engine for Dancer

package Dancer::Logger::Diag;
use Moo;
use Test::More;
with 'Dancer::Core::Role::Logger';

sub _log {
    my ($self, $level, $message) = @_;

    Test::More::diag(
        $self->format_message( $level => $message )
    );
}

1;

__END__

=pod

=head1 SYNOPSIS

=head1 DESCRIPTION

This logging engine uses L<Test::More>'s diag() to output as TAP comments.

This is very useful in case you're writing a test and want to have logging
messages as part of your TAP.

=head1 METHODS

=head2 _log

Use Test::More's diag() to output the log message.

=cut
