use strict;
use warnings;
use Test::More tests => 46;
use Test::Fatal;
use Dancer::Core::Types;


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
    use Dancer::Core::Types;
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

is(exception { DancerPrefix->('/foo') }, undef, 'DancerPrefix',);

like(
    exception { DancerPrefix->('bar/something') },
    qr{bar/something is not a DancerPrefix},
    'DancerPrefix fail',
);

# see DancerPrefix definition, undef is a valid value
like(
    exception { DancerPrefix->(undef) },
    qr/undef is not a DancerPrefix/,
    'DancerPrefix does not accept undef value',
);

is(exception { DancerAppName->('Foo') }, undef, 'DancerAppName',);

is(exception { DancerAppName->('Foo::Bar') }, undef, 'DancerAppName',);

is(exception { DancerAppName->('Foo::Bar::Baz') }, undef, 'DancerAppName',);

like(
    exception { DancerAppName->('Foo:Bar') },
    qr{Foo:Bar is not a DancerAppName},
    'DancerAppName fails with single colons',
);

like(
    exception { DancerAppName->('Foo:::Bar') },
    qr{Foo:::Bar is not a DancerAppName},
    'DancerAppName fails with tripe colons',
);

like(
    exception { DancerAppName->('7Foo') },
    qr{7Foo is not a DancerAppName},
    'DancerAppName fails with beginning number',
);

like(
    exception { DancerAppName->('Foo::45Bar') },
    qr{Foo::45Bar is not a DancerAppName},
    'DancerAppName fails with beginning number',
);

like(
    exception { DancerAppName->('-F') },
    qr{-F is not a DancerAppName},
    'DancerAppName fails with special character',
);

like(
    exception { DancerAppName->('Foo::-') },
    qr{Foo::- is not a DancerAppName},
    'DancerAppName fails with special character',
);

like(
    exception { DancerAppName->('Foo^') },
    qr{\QFoo^\E is not a DancerAppName},
    'DancerAppName fails with special character',
);

ok( exception { DancerAppName->(undef) },
    'DancerAppName does not accept undef value',
);

like(
    exception { DancerAppName->('') },
    qr{Empty string is not a DancerAppName},
    'DancerAppName fails an empty string value',
);

is(exception { DancerMethod->('post') }, undef, 'DancerMethod',);

like(
    exception { DancerMethod->('POST') },
    qr{POST is not a DancerMethod},
    'DancerMethod fail',
);

ok( exception { DancerMethod->(undef) },
    'DancerMethod does not accept undef value',
);

is(exception { DancerHTTPMethod->('POST') }, undef, 'DancerHTTPMethod',);

like(
    exception { DancerHTTPMethod->('post') },
    qr{post is not a DancerHTTPMethod},
    'DancerHTTPMethod fail',
);

ok( exception { DancerHTTPMethod->(undef) },
    'DancerMethod does not accept undef value',
);
