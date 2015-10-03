use strict;
use warnings;
use Test::More;

use Capture::Tiny 0.12 'capture_stderr';
use Dancer2::Logger::Console;

my $file = __FILE__;
my $l = Dancer2::Logger::Console->new(
    app_name => 'test',
    log_level => 'core'
);

for my $level (qw{core debug info warning error}) {
    my $stderr = capture_stderr { $l->$level("$level") };

    # We are dealing directly with the logger, not through the DSL.
    # Skipping 5 stack frames is likely to point to somewhere outside
    # this test; however Capture::Tiny adds in several call frames
    # (see below) to capture the output, giving a reasonable caller
    # to test for
    like $stderr, qr{$level in \Q$file\E l[.] 15}, "$level message sent";
}
done_testing;

__END__

# Stack frames involved where Role::Logger executes caller(5):
#   Dancer2::Core::Role::Logger::format_message(Dancer2::Logger::Console=HASH(0x7f8e41029c60), "error", "error") called at lib/Dancer2/Logger/Console.pm line 10
#   Dancer2::Logger::Console::log(Dancer2::Logger::Console=HASH(0x7f8e41029c60), "error", "error") called at lib/Dancer2/Core/Role/Logger.pm line 183
#   Dancer2::Core::Role::Logger::error(Dancer2::Logger::Console=HASH(0x7f8e41029c60), "error") called at t/logger_console.t line 12
#   main::__ANON__() called at Capture/Tiny.pm line 369
#   eval {...} called at Capture/Tiny.pm line 369
#   Capture::Tiny::_capture_tee(0, 1, 0, 0, CODE(0x7f8e418181e0)) called at t/logger_console.t line 12
