use Test::More;
use strict;
use warnings;

{
    package Dancer::Core::Role::Template;
    use Moo::Role;
    with 'Dancer::Core::Role::Engine';
    requires 'render';

    package Dancer::Template::Tiny;
    use Moo;
    with 'Dancer::Core::Role::Template';

    sub name { 'Tiny' }
    sub type { 'Template' }
    sub render { "tiny" }
    sub supported_hooks { }
}

my $f = Dancer::Template::Tiny->new();
isa_ok $f, 'Dancer::Template::Tiny';
ok($f->does('Dancer::Core::Role::Engine'));
ok($f->does('Dancer::Core::Role::Template'));

is $f->name, 'Tiny';
is $f->type, 'Template';

done_testing;
