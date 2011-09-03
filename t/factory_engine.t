use Test::More;
use strict;
use warnings;

use Dancer::Factory::Engine;

is Dancer::Factory::Engine::_camelize('foo_bar_baz'), 'FooBarBaz';
is Dancer::Factory::Engine::_camelize('FooBarBaz'), 'FooBarBaz';

eval { my $l = Dancer::Factory::Engine->build(unknown => 'stuff') };
like $@, qr{Unable to load class for Unknown engine Stuff: Can't locate};

my $l = Dancer::Factory::Engine->build(logger => 'console');
isa_ok $l, 'Dancer::Logger::Console';

done_testing;
