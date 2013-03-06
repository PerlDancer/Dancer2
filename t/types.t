use strict;
use warnings;
use Test::More tests => 46;
use Test::Fatal;
use Dancer2::Core::Types;


ok(exception { Str->(undef) }, 'Str does not accept undef value',);

is(exception { Str->('something') }, undef, 'Str',);

like(exception { Str->({foo => 'something'}) },
    qr{HASH\(\w+\) is not a string}, 'Str',);

is(exception { Num->(34) }, undef, 'Num',);

ok(exception { Num->(undef) }, 'Num does not accept undef value',);

like(
    exception { Num->('not a number') },
    qr{(?i:not a number is not a Number)},
    'Num fail',
);

is(exception { Bool->(1) }, undef, 'Bool true value',);

is(exception { Bool->(0) }, undef, 'Bool false value',);

is(exception { Bool->(undef) }, undef, 'Bool does accepts undef value',);

like(exception { Bool->('2') }, qr{2 is not a Boolean}, 'Bool fail',);

is(exception { RegexpRef->(qr{.*}) }, undef, 'Regexp',);

like(
    exception { RegexpRef->('/.*/') },
    qr{\Q/.*/\E is not a RegexpRef},
    'Regexp fail',
);

ok(exception { RegexpRef->(undef) }, 'Regexp does not accept undef value',);

is(exception { HashRef->({goo => 'le'}) }, undef, 'HashRef',);

like(
    exception { HashRef->('/.*/') },
    qr{\Q/.*/\E is not a HashRef},
    'HashRef fail',
);

ok(exception { HashRef->(undef) }, 'HashRef does not accept undef value',);

is(exception { ArrayRef->([1, 2, 3, 4]) }, undef, 'ArrayRef',);

like(
    exception { ArrayRef->('/.*/') },
    qr{\Q/.*/\E is not an ArrayRef},
    'ArrayRef fail',
);

ok(exception { ArrayRef->(undef) }, 'ArrayRef does not accept undef value',);

is( exception {
        CodeRef->(sub {44});
    },
    undef,
    'CodeRef',
);

like(
    exception { CodeRef->('/.*/') },
    qr{\Q/.*/\E is not a CodeRef},
    'CodeRef fail',
);

ok(exception { CodeRef->(undef) }, 'CodeRef does not accept undef value',);

{

    package InstanceChecker::zad7;
    use Moo;
    use Dancer2::Core::Types;
    has foo => (is => 'ro', isa => InstanceOf ['Foo']);
}

is(exception { InstanceChecker::zad7->new(foo => bless {}, 'Foo') },
    undef, 'InstanceOf',);

like(
    exception { InstanceChecker::zad7->new(foo => bless {}, 'Bar') },
    qr{Bar=HASH\(\w+\) is not an instance of the class: Foo},
    'InstanceOf fail',
);

ok( exception { InstanceOf('Foo')->(undef) },
    'InstanceOf does not accept undef value',
);

is(exception { Dancer2Prefix->('/foo') }, undef, 'Dancer2Prefix',);

like(
    exception { Dancer2Prefix->('bar/something') },
    qr{bar/something is not a Dancer2Prefix},
    'Dancer2Prefix fail',
);

# see Dancer2Prefix definition, undef is a valid value
like(
    exception { Dancer2Prefix->(undef) },
    qr/undef is not a Dancer2Prefix/,
    'Dancer2Prefix does not accept undef value',
);

is(exception { Dancer2AppName->('Foo') }, undef, 'Dancer2AppName',);

is(exception { Dancer2AppName->('Foo::Bar') }, undef, 'Dancer2AppName',);

is(exception { Dancer2AppName->('Foo::Bar::Baz') }, undef, 'Dancer2AppName',);

like(
    exception { Dancer2AppName->('Foo:Bar') },
    qr{Foo:Bar is not a Dancer2AppName},
    'Dancer2AppName fails with single colons',
);

like(
    exception { Dancer2AppName->('Foo:::Bar') },
    qr{Foo:::Bar is not a Dancer2AppName},
    'Dancer2AppName fails with tripe colons',
);

like(
    exception { Dancer2AppName->('7Foo') },
    qr{7Foo is not a Dancer2AppName},
    'Dancer2AppName fails with beginning number',
);

like(
    exception { Dancer2AppName->('Foo::45Bar') },
    qr{Foo::45Bar is not a Dancer2AppName},
    'Dancer2AppName fails with beginning number',
);

like(
    exception { Dancer2AppName->('-F') },
    qr{-F is not a Dancer2AppName},
    'Dancer2AppName fails with special character',
);

like(
    exception { Dancer2AppName->('Foo::-') },
    qr{Foo::- is not a Dancer2AppName},
    'Dancer2AppName fails with special character',
);

like(
    exception { Dancer2AppName->('Foo^') },
    qr{\QFoo^\E is not a Dancer2AppName},
    'Dancer2AppName fails with special character',
);

ok( exception { Dancer2AppName->(undef) },
    'Dancer2AppName does not accept undef value',
);

like(
    exception { Dancer2AppName->('') },
    qr{Empty string is not a Dancer2AppName},
    'Dancer2AppName fails an empty string value',
);

is(exception { Dancer2Method->('post') }, undef, 'Dancer2Method',);

like(
    exception { Dancer2Method->('POST') },
    qr{POST is not a Dancer2Method},
    'Dancer2Method fail',
);

ok( exception { Dancer2Method->(undef) },
    'Dancer2Method does not accept undef value',
);

is(exception { Dancer2HTTPMethod->('POST') }, undef, 'Dancer2HTTPMethod',);

like(
    exception { Dancer2HTTPMethod->('post') },
    qr{post is not a Dancer2HTTPMethod},
    'Dancer2HTTPMethod fail',
);

ok( exception { Dancer2HTTPMethod->(undef) },
    'Dancer2Method does not accept undef value',
);
