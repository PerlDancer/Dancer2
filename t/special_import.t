use strict;
use warnings;
use Test::More import => ['!pass'];

use Dancer2 qw(:tests);
use Dancer2::Test;

eval "
    any ['get', 'post'], '/'  => sub {
        request->method;
        pass;
    };
";

like(
    $@,
    qr{Bareword "pass" not allowed while "strict subs"},
    'pass were not imported'
);

done_testing;
