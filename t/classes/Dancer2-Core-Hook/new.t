#!perl

use strict;
use warnings;

use Test::More tests => 12;
use Test::Fatal;

use_ok('Dancer2::Core::Hook');

like(
    exception { Dancer2::Core::Hook->new( name => 'myname' ) },
    qr/^Missing required arguments: code/,
    'Must provide code attribute',
);

like(
    exception { Dancer2::Core::Hook->new( code => sub {1} ) },
    qr/^Missing required arguments: name/,
    'Must provide name attribute',
);

is(
    exception {
        Dancer2::Core::Hook->new( name => 'myname', code => sub {1} )
    },
    undef,
    'Can create hook with name and code',
);

{
    my $hook = Dancer2::Core::Hook->new(
        name => 'before_template',
        code => sub {
            my $input = shift;
            ::is( $input, 'input', 'Correct input for hook' );
            return 'output';
        },
    );

    isa_ok( $hook, 'Dancer2::Core::Hook' );
    can_ok( $hook, qw<name code> );

    is(
        $hook->name,
        'before_template_render',
        'before_template becomes before_template_render',
    );

    isa_ok( $hook->code, 'CODE' );

    is(
        $hook->code->('input'),
        'output',
        'Hook returned proper output',
    );
}

{
    my $hook = Dancer2::Core::Hook->new(
        name => 'CrashingHook',
        code => sub { die 'dying' },
    );

    isa_ok( $hook, 'Dancer2::Core::Hook' );

    like(
        exception { $hook->code->() },
        qr/^Hook error: dying/,
        'Hook crashing caught',
    );
}
