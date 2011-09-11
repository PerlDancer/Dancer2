use strict;
use warnings;
use Test::More;
use Test::Trap;

use Dancer::Logger::Console;
my $l = Dancer::Logger::Console->new;

trap { $l->debug("debug") };
like $trap->stderr, qr{debug in t/logger_console.t}, 
    "debug message sent";

done_testing;
