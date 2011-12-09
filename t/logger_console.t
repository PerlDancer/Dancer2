use strict;
use warnings;
use Test::More;

eval { require Test::Trap };
if ($@) {
    plan skip_all => "Test::Trap is required to run these tests";
}

plan tests => 4;

use Dancer::Logger::Console;
my $l = Dancer::Logger::Console->new(log_level => 'core');

for my $level (qw{core debug warning error}) {
    trap { $l->$level("$level") };
    like $trap->stderr, qr{$level in t/logger_console.t},
        "$level message sent";
}
done_testing;
