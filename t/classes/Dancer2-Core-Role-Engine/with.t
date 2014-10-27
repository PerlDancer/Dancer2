#!perl

use strict;
use warnings;

use Test::More tests => 4;

{
    package App;
    use Moo;
    with 'Dancer2::Core::Role::Engine';
    sub supported_hooks {}
}

my $app = App->new;
isa_ok( $app, 'App' );
can_ok( $app, qw<session config> ); # attributes
can_ok( $app, qw<set_session clear_session has_session> ); # methods
ok(
    $app->DOES('Dancer2::Core::Role::Hookable'),
    'App consumes Dancer2::Core::Role::Hookable',
);

