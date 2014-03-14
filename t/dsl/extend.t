#!/usr/bin/env perl

# define a sample DSL extension that will be used in the rest of these test
# This extends Dancer2::Core::DSL but provides an extra keyword
#
# Each test below creates a new package so it can load Dancer2
BEGIN {

    package Dancer2::Test::ExtendedDSL;

    use Moo;
    extends 'Dancer2::Core::DSL';

    sub BUILD {
        my ( $self ) = @_;
        $self->register(foo => 1);
    }

    sub foo {
        return $_[1];
    }
}

package main;

use Test::More tests => 5;

package test1;
use Test::More;

use Dancer2 dsl => 'Dancer2::Test::ExtendedDSL';

ok(defined &foo, 'use line dsl can foo');
is(foo('bar'), 'bar', 'use line Foo returns bar');

package test2;
use Test::More;

ok(!defined &foo, 'intermediate package has no polluted namespace');

package test3;
use Test::More;
use FindBin;
use File::Spec;

BEGIN {
    $ENV{DANCER_CONFDIR} = File::Spec->catdir($FindBin::Bin, 'extend_config');
}

use Dancer2;

ok(defined &foo, 'config specified DSL can foo');
is(foo('baz'), 'baz', 'config specified Foo returns baz');

done_testing;
