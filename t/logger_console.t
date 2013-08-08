use strict;
use warnings;
use Test::More;

use Capture::Tiny 0.12 'capture_stderr';
use Dancer2::Logger::Console;

my $l =
  Dancer2::Logger::Console->new( app_name => 'test', log_level => 'core' );

for my $level (qw{core debug warning error}) {
    my $stderr = capture_stderr { $l->$level("$level") };

    # Again, we are dealing directly with the logger, not through the
    # DSL, so the caller(6) stack has a different size
    like $stderr, qr{$level in -}, "$level message sent";
}
done_testing;
