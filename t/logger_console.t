use strict;
use warnings;
use Test::More;
use Capture::Tiny 0.12 'capture_stderr';

plan tests => 4;

use Dancer2::Logger::Console;
my $l =
  Dancer2::Logger::Console->new( app_name => 'test', log_level => 'core' );

for my $level (qw{core debug warning error}) {
    my $stderr = capture_stderr { $l->$level("$level") };
    like $stderr, qr{$level in t/logger_console.t}, "$level message sent";
}
done_testing;
