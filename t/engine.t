use strict;
use warnings;
use Test::More;
use Dancer2::Template::Tiny;

my $f = Dancer2::Template::Tiny->new();
isa_ok $f, 'Dancer2::Template::Tiny';
ok( $f->does('Dancer2::Core::Role::Engine') );
ok( $f->does('Dancer2::Core::Role::Template') );

is $f->name, 'Tiny';

done_testing;
