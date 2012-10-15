# ABSTRACT: blackhole-like silent logging engine for Dancer

package Dancer::Logger::Null;
use Moo;
with 'Dancer::Core::Role::Logger';

sub log {1}

1;

__END__


=head1 SYNOPSIS

=head1 DESCRIPTION

This logger acts as a blackhole (or /dev/null, if you will) that discards all
the log messages instead of displaying them anywhere.

=head1 METHODS

=head2 _log

Discards the message.

=cut
