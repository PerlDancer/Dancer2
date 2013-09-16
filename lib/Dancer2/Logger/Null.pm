# ABSTRACT: Blackhole-like silent logging engine for Dancer2

package Dancer2::Logger::Null;
use Moo;
with 'Dancer2::Core::Role::Logger';

=head1 DESCRIPTION

This logger acts as a blackhole (or /dev/null, if you will) that discards all
the log messages instead of displaying them anywhere.

=method log

Discards the message.

=cut

sub log {1}

1;
