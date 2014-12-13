use strict;
use warnings;
use Test::More tests => 1;
use Test::Fatal;

require Dancer2;

is(
    exception { Dancer2->import() },
    undef,
    'No compilation issue',
);

