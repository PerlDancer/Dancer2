use strict;
use warnings;
use Test::More tests => 46;
use Test::Fatal;
use Dancer::Moo::Types;

is(
    exception { Str->(undef) },
    undef,
    'Str accepts undef value',
);

is(
    exception { Str->('something') },
    undef,
    'Str',
);

like(
    exception { Str->({foo => 'something'}) },
    qr{does not pass the type constraint check for type `Str'},
    'Str',
);

is(
    exception { Num->(34) },
    undef,
    'Num',
);

is(
    exception { Num->(undef) },
    undef,
    'Num accepts undef value',
);

like(
    exception { Num->('not a number') },
    qr{does not pass the type constraint check for type `Num'},
    'Num fail',
);

is(
    exception { Bool->(1) },
    undef,
    'Bool true value',
);

is(
    exception { Bool->(0) },
    undef,
    'Bool false value',
);

is(
    exception { Bool->(undef) },
    undef,
    'Bool accepts undef value',
);

like(
    exception { Bool->('2') },
    qr{does not pass the type constraint check for type `Bool'},
    'Bool fail',
);

is(
    exception { Regexp->(qr{.*}) },
    undef,
    'Regexp',
);

like(
    exception { Regexp->('/.*/') },
    qr{does not pass the type constraint check for type `Regexp'},
    'Regexp fail',
);

is(
    exception { Regexp->(undef) },
    undef,
    'Regexp accepts undef value',
);

is(
    exception { HashRef->({goo => 'le'}) },
    undef,
    'HashRef',
);

like(
    exception { HashRef->('/.*/') },
    qr{does not pass the type constraint check for type `HashRef'},
    'HashRef fail',
);

is(
    exception { HashRef->(undef) },
    undef,
    'HashRef accepts undef value',
);

is(
    exception { ArrayRef->([1, 2, 3, 4 ]) },
    undef,
    'ArrayRef',
);

like(
    exception { ArrayRef->('/.*/') },
    qr{does not pass the type constraint check for type `ArrayRef'},
    'ArrayRef fail',
);

is(
    exception { ArrayRef->(undef) },
    undef,
    'ArrayRef accepts undef value',
);

is(
    exception { CodeRef->( sub { 44 } ) },
    undef,
    'CodeRef',
);

like(
    exception { CodeRef->('/.*/') },
    qr{does not pass the type constraint check for type `CodeRef'},
    'CodeRef fail',
);

is(
    exception { CodeRef->(undef) },
    undef,
    'CodeRef accepts undef value',
);

{ package Foo; }
{ package Bar; }
my $f = bless {}, 'Foo';
my $b = bless {}, 'Bar';

is(
    exception { ObjectOf('Foo')->($f) },
    undef,
    'ObjectOf',
);

like(
    exception { ObjectOf('Foo')->($b) },
    qr{does not pass the type constraint check for type `ObjectOf\(Foo\)'},
    'ObjectOf fail',
);

is(
    exception { ObjectOf('Foo')->(undef) },
    undef,
    'ObjectOf accepts undef value',
);

is(
    exception { DancerPrefix->('/foo') },
    undef,
    'DancerPrefix',
);

like(
    exception { DancerPrefix->('bar/something') },
    qr{does not pass the type constraint check for type `DancerPrefix'},
    'DancerPrefix fail',
);

is(
    exception { DancerPrefix->(undef) },
    undef,
    'DancerPrefix accepts undef value',
);

is(
    exception { DancerAppName->('Foo') },
    undef,
    'DancerAppName',
);

is(
    exception { DancerAppName->('Foo::Bar') },
    undef,
    'DancerAppName',
);

is(
    exception { DancerAppName->('Foo::Bar::Baz') },
    undef,
    'DancerAppName',
);

like(
    exception { DancerAppName->('Foo:Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with single colons',
);

like(
    exception { DancerAppName->('Foo:::Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with tripe colons',
);

like(
    exception { DancerAppName->('7Foo') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with beginning number',
);

like(
    exception { DancerAppName->('Foo::45Bar') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with beginning number',
);

like(
    exception { DancerAppName->('-F') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

like(
    exception { DancerAppName->('Foo::-') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

like(
    exception { DancerAppName->('Foo^') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails with special character',
);

is(
    exception { DancerAppName->(undef) },
    undef,
    'DancerAppName accepts undef value',
);

like(
    exception { DancerAppName->('') },
    qr{does not pass the type constraint check for type `DancerAppName'},
    'DancerAppName fails an empty string value',
);

is(
    exception { DancerMethod->('post') },
    undef,
    'DancerMethod',
);

like(
    exception { DancerMethod->('POST') },
    qr{does not pass the type constraint check for type `DancerMethod'},
    'DancerMethod fail',
);

is(
    exception { DancerMethod->(undef) },
    undef,
    'DancerMethod accepts undef value',
);

is(
    exception { DancerHTTPMethod->('POST') },
    undef,
    'DancerMethod',
);

like(
    exception { DancerHTTPMethod->('post') },
    qr{does not pass the type constraint check for type `DancerMethod'},
    'DancerMethod fail',
);

is(
    exception { DancerHTTPMethod->(undef) },
    undef,
    'DancerMethod accepts undef value',
);

