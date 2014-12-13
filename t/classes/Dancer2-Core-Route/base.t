use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer2::Core::Route;

plan tests => 1;

like(
    exception { Dancer2::Core::Route->new( regexp => 'no+leading+slash' ) },
    qr/^regexp must begin with/,
    'route pattern must start with a /',
);
