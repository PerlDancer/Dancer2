package Dancer2::Logger::Null;
# ABSTRACT: Blackhole-like silent logging engine for Dancer2

use Moo;
with 'Dancer2::Core::Role::Logger';

sub log {1}

1;

__END__

=head1 DESCRIPTION

This logger acts as a blackhole (or /dev/null, if you will) that discards all
the log messages instead of displaying them anywhere.

=method log

Discards the message.

=cut
