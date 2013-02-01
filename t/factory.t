use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer::Core::Factory;

is Dancer::Core::Factory::_camelize('foo_bar_baz'), 'FooBarBaz';
is Dancer::Core::Factory::_camelize('FooBarBaz'),   'FooBarBaz';

like(
    exception { my $l = Dancer::Core::Factory->create(unknown => 'stuff') },
    qr{Unable to load class for Unknown component Stuff: Can't locate},
    'Failure to load nonexistent class',
);

my $l = Dancer::Core::Factory->create(logger => 'console');
isa_ok $l, 'Dancer::Logger::v2::Console';

done_testing;
