use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer2::Core::Factory;

is Dancer2::Core::Factory::_camelize('foo_bar_baz'), 'FooBarBaz';
is Dancer2::Core::Factory::_camelize('FooBarBaz'),   'FooBarBaz';

like(
    exception { my $l = Dancer2::Core::Factory->create( unknown => 'stuff' ) },
    qr{Unable to load class for Unknown component Stuff:},
    'Failure to load nonexistent class',
);

my $l = Dancer2::Core::Factory->create( logger => 'console' );
isa_ok $l, 'Dancer2::Logger::Console';

done_testing;
