use strict;
use warnings;
use Test::More tests => 1;
use Test::Fatal;

require Dancer2;

like(
    exception { Dancer2->import() },
    qr{Engine 'foo' is not supported},
    'Correct compilation issue',
);

