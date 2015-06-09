package Dancer2::Logger::Diag;
# ABSTRACT: Test::More diag() logging engine for Dancer2
$Dancer2::Logger::Diag::VERSION = '0.159002';
use Moo;
use Test::More;

with 'Dancer2::Core::Role::Logger';

sub log {
    my ( $self, $level, $message ) = @_;

    Test::More::diag( $self->format_message( $level => $message ) );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Logger::Diag - Test::More diag() logging engine for Dancer2

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This logging engine uses L<Test::More>'s diag() to output as TAP comments.

This is very useful in case you're writing a test and want to have logging
messages as part of your TAP.

=head1 METHODS

=head2 log

Use Test::More's diag() to output the log message.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
