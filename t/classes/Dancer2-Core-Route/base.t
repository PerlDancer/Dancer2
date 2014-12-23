use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer2::Core::Route;

plan tests => 2;

is(
    exception {
        Dancer2::Core::Route->new(
            regexp => 'no+leading+slash',
            method => 'get',
            code   => sub {1},
        )
    },
    undef,
    'route pattern can start with a / or not',
);

is(
    exception {
        Dancer2::Core::Route->new(
            regexp => '',
            method => 'get',
            code   => sub {1},
        )
    },
    undef,
    'route pattern can also be empty',
);

