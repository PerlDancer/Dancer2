package Dancer2::Logger::Null;
# ABSTRACT: Blackhole-like silent logging engine for Dancer2
$Dancer2::Logger::Null::VERSION = '0.159002';
use Moo;
with 'Dancer2::Core::Role::Logger';

sub log {1}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Logger::Null - Blackhole-like silent logging engine for Dancer2

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

This logger acts as a blackhole (or /dev/null, if you will) that discards all
the log messages instead of displaying them anywhere.

=head1 METHODS

=head2 log

Discards the message.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
