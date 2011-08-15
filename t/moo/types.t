use strict;
use warnings;
use Test::More tests => 22;
use Dancer::Moo::Types;

eval { Dancer::Moo::Types::Str('something') };
is $@, '', 'Str';

eval { Dancer::Moo::Types::Num(34) };
is $@, '', 'Num';

eval { Dancer::Moo::Types::Num('not a number') };
like $@, qr{does not pass the type constraint check for type `Num'}, 'Num fail';

eval { Dancer::Moo::Types::Bool(1) };
is $@, '', 'Bool true value';

eval { Dancer::Moo::Types::Bool(0) };
is $@, '', 'Bool false value';

eval { Dancer::Moo::Types::Bool('2') };
like $@, qr{does not pass the type constraint check for type `Bool'}, 'Bool fail';

eval { Dancer::Moo::Types::Regexp(qr{.*}) };
is $@, '', 'Regexp';

eval { Dancer::Moo::Types::Regexp('/.*/') };
like $@, qr{does not pass the type constraint check for type `Regexp'}, 'Regexp fail';

eval { Dancer::Moo::Types::HashRef({goo => 'le'}) };
is $@, '', 'HashRef';

eval { Dancer::Moo::Types::HashRef('/.*/') };
like $@, qr{does not pass the type constraint check for type `HashRef'}, 'HashRef fail';

eval { Dancer::Moo::Types::ArrayRef([1, 2, 3, 4 ]) };
is $@, '', 'ArrayRef';

eval { Dancer::Moo::Types::ArrayRef('/.*/') };
like $@, qr{does not pass the type constraint check for type `ArrayRef'}, 'ArrayRef fail';

eval { Dancer::Moo::Types::CodeRef( sub { 44 } ) };
is $@, '', 'CodeRef';

eval { Dancer::Moo::Types::CodeRef('/.*/') };
like $@, qr{does not pass the type constraint check for type `CodeRef'}, 'CodeRef fail';

{ package Foo; }
{ package Bar; }
my $f = bless {}, 'Foo'; 
my $b = bless {}, 'Bar'; 

eval { Dancer::Moo::Types::ObjectOf( Foo => $f) };
is $@, '', 'ObjectOf';

eval { Dancer::Moo::Types::ObjectOf( Foo => $b) };
like $@, qr{does not pass the type constraint check for type `ObjectOf\(Foo\)'},
    'ObjectOf fail';


eval { Dancer::Moo::Types::DancerPrefix('/foo') };
is $@, '', 'DancerPrefix';

eval { Dancer::Moo::Types::DancerPrefix('bar/something') };
like $@, qr{does not pass the type constraint check for type `DancerPrefix'}, 
    'DancerPrefix fail';

eval { Dancer::Moo::Types::DancerAppName('Foo') };
is $@, '', 'DancerAppName';

eval { Dancer::Moo::Types::DancerAppName('') };
like $@, qr{does not pass the type constraint check for type `DancerAppName'}, 
    'DancerAppName fail';

eval { Dancer::Moo::Types::DancerMethod('post') };
is $@, '', 'DancerMethod';

eval { Dancer::Moo::Types::DancerMethod('FAIL') };
like $@, qr{does not pass the type constraint check for type `DancerMethod'}, 
    'DancerMethod fail';

