use strict;
use warnings;
use Test::More tests => 46;
use Test::Fatal;
use Dancer::Moo::Types;

is(
    exception { Dancer::Moo::Types::Str(undef) },
    undef,
    'Str accepts undef value',
);

is(
    exception { Dancer::Moo::Types::Str('something') },
    undef,
    'Str',
);

like(
    exception { Dancer::Moo::Types::Str({foo => 'something'}) },
    qr{does not pass the type constraint check for type `Str'},
    'Str',
);

is(
    exception { Dancer::Moo::Types::Num(34) },
    undef,
    'Num',
);

is(
    exception { Dancer::Moo::Types::Num(undef) },
    undef,
    'Num accepts undef value',
);

like(
    exception { Dancer::Moo::Types::Num('not a number') },
    qr{does not pass the type constraint check for type `Num'},
    'Num fail',
);

is(
    exception { Dancer::Moo::Types::Bool(1) },
    undef,
    'Bool true value',
);

is(
    exception { Dancer::Moo::Types::Bool(0) },
    undef,
    'Bool false value',
);

is(
    exception { Dancer::Moo::Types::Bool(undef) },
    undef,
    'Bool accepts undef value',
);

like(
    exception { Dancer::Moo::Types::Bool('2') },
    qr{does not pass the type constraint check for type `Bool'},
    'Bool fail',
);

is(
    exception { Dancer::Moo::Types::Regexp(qr{.*}) },
    undef,
    'Regexp',
);

like(
    exception { Dancer::Moo::Types::Regexp('/.*/') },
    qr{does not pass the type constraint check for type `Regexp'},
    'Regexp fail',
);

is(
    exception { Dancer::Moo::Types::Regexp(undef) },
    undef,
    'Regexp accepts undef value',
);

is(
    exception { Dancer::Moo::Types::HashRef({goo => 'le'}) },
    undef,
    'HashRef',
);

like(
    exception { Dancer::Moo::Types::HashRef('/.*/') },
    qr{does not pass the type constraint check for type `HashRef'},
    'HashRef fail',
);

is(
    exception { Dancer::Moo::Types::HashRef(undef) },
    undef,
    'HashRef accepts undef value',
);

is(
    exception { Dancer::Moo::Types::ArrayRef([1, 2, 3, 4 ]) },
    undef,
    'ArrayRef',
);

like(
    exception { Dancer::Moo::Types::ArrayRef('/.*/') },
    qr{does not pass the type constraint check for type `ArrayRef'},
    'ArrayRef fail',
);

is(
    exception { Dancer::Moo::Types::ArrayRef(undef) },
    undef,
    'ArrayRef accepts undef value',
);

is(
    exception { Dancer::Moo::Types::CodeRef( sub { 44 } ) },
    undef,
    'CodeRef',
);

like(
    exception { Dancer::Moo::Types::CodeRef('/.*/') },
    qr{does not pass the type constraint check for type `CodeRef'},
    'CodeRef fail',
);

is(
    exception { Dancer::Moo::Types::CodeRef(undef) },
    undef,
    'CodeRef accepts undef value',
);

{ package Foo; }
{ package Bar; }
my $f = bless {}, 'Foo';
my $b = bless {}, 'Bar';

is(
    exception { Dancer::Moo::Types::ObjectOf( Foo => $f) },
    undef,
    'ObjectOf',
);

like(
    exception { Dancer::Moo::Types::ObjectOf( Foo => $b) },
    qr{does not pass the type constraint check for type `ObjectOf\(Foo\)'},
    'ObjectOf fail',
);

is(
    exception { Dancer::Moo::Types::ObjectOf(Foo => undef) },
    undef,
    'ObjectOf accepts undef value',
);

is(
    exception { Dancer::Moo::Types::DancerPrefix('/foo') },
    undef,
    'DancerPrefix',
);

like(
    exception { Dancer::Moo::Types::DancerPrefix('bar/something') },
    qr{does not pass the type constraint check for type `DancerPrefix'},
    'DancerPrefix fail',
);

is(
    exception { Dancer::Moo::Types::DancerPrefix(undef) },
    undef,
    'DancerPrefix accepts undef value',
);

is(
    exception { Dancer::Moo::Types::DancerAppName('Foo') },
    undef,
    'DancerAppName',
);

is(
    exception { Dancer::Moo::Types::DancerAppName('Foo::Bar') },
    undef,
    'DancerAppName',
);

is(
    exception { Dancer::Moo::Types::DancerAppName('Foo::Bar::Baz') },
    undef,
    'DancerAppName',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('Foo:Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with single colons',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('Foo:::Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with tripe colons',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('7Foo') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with beginning number',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('Foo::45Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with beginning number',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('-F') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('Foo::-') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('Foo^') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

is(
    exception { Dancer::Moo::Types::DancerAppName(undef) },
    undef,
    'DancerAppName accepts undef value',
);

like(
    exception { Dancer::Moo::Types::DancerAppName('') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails an empty string value',
);

is(
    exception { Dancer::Moo::Types::DancerMethod('post') },
    undef,
    'DancerMethod',
);

like(
    exception { Dancer::Moo::Types::DancerMethod('POST') },
    qr{does not pass the type constraint check for type `DancerMethod'},
    'DancerMethod fail',
);

is(
    exception { Dancer::Moo::Types::DancerMethod(undef) },
    undef,
    'DancerMethod accepts undef value',
);

is(
    exception { Dancer::Moo::Types::DancerHTTPMethod('POST') },
    undef,
    'DancerMethod',
);

like(
    exception { Dancer::Moo::Types::DancerHTTPMethod('post') },
    qr{does not pass the type constraint check for type `DancerMethod'},
    'DancerMethod fail',
);

is(
    exception { Dancer::Moo::Types::DancerHTTPMethod(undef) },
    undef,
    'DancerMethod accepts undef value',
);

