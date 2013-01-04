use strict;
use warnings;
use Test::More;
use Dancer::Template::Tiny;

my $f = Dancer::Template::Tiny->new();
isa_ok $f, 'Dancer::Template::Tiny';
ok($f->does('Dancer::Core::Role::Engine'));
ok($f->does('Dancer::Core::Role::Template'));

is $f->name, 'Tiny';

done_testing;
