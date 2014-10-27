#!perl

use strict;
use warnings;

use Test::More tests => 3;

{
    package Handler;
    use Moo;
    with 'Dancer2::Core::Role::Handler';
    sub register {}
}

my $handler = Handler->new;
isa_ok( $handler, 'Handler' );
can_ok( $handler, qw<app>   ); # attributes
ok(
    $handler->DOES('Dancer2::Core::Role::Handler'),
    'Handler consumes Dancer2::Core::Role::Handler',
);

