# time.t

use strict;
use warnings;
use Test::More;

my $mocked_epoch = 1355676244; # "Sun, 16-Dec-2012 16:44:04 GMT"

# The order is important!
use Test::MockTime 'set_absolute_time';
set_absolute_time( $mocked_epoch );
use Dancer::Core::Time;

my @tests = (
    ["1h" => 3600 => "Sun, 16-Dec-2012 17:44:04 GMT"],
    ["1 hour" => 3600 => "Sun, 16-Dec-2012 17:44:04 GMT"],
    ["1 hours" => 3600 => "Sun, 16-Dec-2012 17:44:04 GMT"],

    ["1d" => (3600 * 24) => "Mon, 17-Dec-2012 16:44:04 GMT" ],
    ["1 day" => (3600 * 24) => "Mon, 17-Dec-2012 16:44:04 GMT" ],
);

foreach my $test (@tests) {
    my ($expr, $secs, $gmt_string) = @$test;

    subtest "Expression: \"$expr\"" => sub {
        my $t = Dancer::Core::Time->new(expression => $expr);
        is $t->seconds, $secs, "\"$expr\" is $secs seconds";
        is $t->epoch, ($t->seconds + $mocked_epoch), "... its epoch is " . $t->epoch;
        is $t->gmt_string, $gmt_string, "... and its GMT string is $gmt_string";
    };
}

done_testing;

