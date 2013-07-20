use strict;
use warnings;
use Test::More import => ['!pass'];

use Dancer2::Test;

my @splat;

{
    use Dancer2;
    get '/*/*/*' => sub {
        @splat = splat;
    };
}

my $resp = dancer_response(
    get => '/foo/bar/baz',
    { params => { foo => 42 }, }
);

is_deeply [@splat], [qw(foo bar baz)], "splat behaves as expected";
is $resp->status,         200, "got a 200";
is_deeply $resp->content, 3,   "got expected response";

done_testing;
