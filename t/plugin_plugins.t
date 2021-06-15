#!perl

use Test::More;

use lib 't/plugins';

use Dancer2;
use Dancer2::Plugins qw(Foo Bar);

is foo(), '123';
is bar(), '456';

done_testing;
