# time.t

use strict;
use warnings;
use Test::More;
use Dancer2::ModuleLoader;

my $mocked_epoch = 1355676244;    # "Sun, 16-Dec-2012 16:44:04 GMT"

# The order is important!
Dancer2::ModuleLoader->require('Test::MockTime')
    or plan skip_all => 'Test::MockTime not present';

Test::MockTime::set_fixed_time($mocked_epoch);
require Dancer2::Core::Time;

my @tests = (
    ["1h"      => 3600  => "Sun, 16-Dec-2012 17:44:04 GMT"],
    ["1 hour"  => 3600  => "Sun, 16-Dec-2012 17:44:04 GMT"],
    ["+1 hour" => 3600  => "Sun, 16-Dec-2012 17:44:04 GMT"],
    ["-1h"     => -3600 => "Sun, 16-Dec-2012 15:44:04 GMT"],
    ["1 hours" => 3600  => "Sun, 16-Dec-2012 17:44:04 GMT"],

    ["1d"    => (3600 * 24) => "Mon, 17-Dec-2012 16:44:04 GMT"],
    ["1 day" => (3600 * 24) => "Mon, 17-Dec-2012 16:44:04 GMT"],


);

foreach my $test (@tests) {
    my ($expr, $secs, $gmt_string) = @$test;

    subtest "Expression: \"$expr\"" => sub {
        my $t = Dancer2::Core::Time->new(expression => $expr);
        is $t->seconds, $secs, "\"$expr\" is $secs seconds";
        is $t->epoch, ($t->seconds + $mocked_epoch),
          "... its epoch is " . $t->epoch;
        is $t->gmt_string, $gmt_string,
          "... and its GMT string is $gmt_string";
    };
}

subtest "Forcing another epoch in the object should work" => sub {
    my $t = Dancer2::Core::Time->new(epoch => 1, expression => "1h");
    is $t->seconds, 3600, "...1h is still 3600 seconds";
    is $t->epoch,   1,    "... epoch is 1";
    is $t->gmt_string, 'Thu, 01-Jan-1970 00:00:01 GMT',
      "... and is expressed as Thu, 01-Jan-1970 00:00:01 GMT";
};

subtest "unparsable strings should be kept" => sub {
    for my $t (
        ["something silly", "something silly", "something silly"],
        ["+2 something",    "+2 something",    "+2 something"],
      )
    {
        my ($expr, $secs, $gmt) = @$t;
        my $t = Dancer2::Core::Time->new(expression => $expr);
        is $t->seconds,    $secs, "\"$expr\" is $secs seconds";
        is $t->epoch,      $expr, "... its epoch is $expr";
        is $t->gmt_string, $gmt,  "... and its GMT string is $gmt";
    }
};

done_testing;
