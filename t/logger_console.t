use strict;
use warnings;
use Test::More;
use Test::Trap;

use Dancer::Logger::Console;
my $l = Dancer::Logger::Console->new(log_level => 'core');

for my $level qw(core debug warning error) {
    trap { $l->$level("$level") };
    like $trap->stderr, qr{$level in t/logger_console.t}, 
        "$level message sent";
}
done_testing;
