use Test::More;
use strict;
use warnings;

BEGIN {
    # Freeze time at Tue, 15-Jun-2010 00:00:00 GMT
    *CORE::GLOBAL::time = sub { return 1276560000 }
}

my $_logs = [];

{
    package Dancer::Logger::Test;
    use Moo;
    with 'Dancer::Core::Role::Logger';

    sub _log {
        my ($self, $level, $message) = @_;
        push @$_logs, $self->format_message($level, $message);
    }
}

my $logger = Dancer::Logger::Test->new();

is $logger->log_level, 'debug';
$logger->debug("foo");
like $_logs->[0], qr{debug \@2010-06-1\d \d\d:00:00> foo in t/logger.t};

done_testing;
