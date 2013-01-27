use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Dancer::Factory::Engine;

is Dancer::Factory::Engine::_camelize('foo_bar_baz'), 'FooBarBaz';
is Dancer::Factory::Engine::_camelize('FooBarBaz'),   'FooBarBaz';

like(
    exception { my $l = Dancer::Factory::Engine->create(unknown => 'stuff') },
    qr{Unable to load class for Unknown engine Stuff: Can't locate},
    'Failure to load nonexistent class',
);

my $l = Dancer::Factory::Engine->create(logger => 'console');
isa_ok $l, 'Dancer::Logger::Console';

done_testing;
