use strict;
use warnings;
use Test::More;
use Dancer::Template::v2::Tiny;

my $f = Dancer::Template::v2::Tiny->new();
isa_ok $f, 'Dancer::Template::v2::Tiny';
ok($f->does('Dancer::Core::Role::Engine'));
ok($f->does('Dancer::Core::Role::Template'));

is $f->name, 'Tiny';
is $f->type, 'Template';

done_testing;
