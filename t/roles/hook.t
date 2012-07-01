use strict;
use warnings;
use Test::More tests => 8;
use Test::Fatal;

use Dancer::Core::Hook;

my $h = Dancer::Core::Hook->new(name => 'before_template', code => sub { 'BT' });
is $h->name, 'before_template_render';
is $h->code->(), 'BT';

{
    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Hookable';
    sub supported_hooks {  'foobar' }
}

my $f = Foo->new;

like(
    exception { $f->execute_hooks() },
    qr{execute_hook needs a hook name},
    'execute_hook needs a hook name',
);

my $count = 0;
my $some_hook = Dancer::Core::Hook->new(
    name => 'foobar',
    code => sub {
        $count++;
    }
);

ok(
    ! exception { $f->add_hook($some_hook) },
    'Supported hook can be installed',
);

like(
    exception {
        $f->add_hook(
            Dancer::Core::Hook->new(
                name => 'unknown_hook',
                code => sub { $count++; }
            ));
    },
    qr{Unsupported hook 'unknown_hook'},
    'Unsupported hook cannot be installed',
);

$f->execute_hooks('foobar');
is $count, 1;

like(
    exception { $f->replace_hooks( 'doesnotexist', [] ) },
    qr{Hook 'doesnotexist' must be installed first},
    'Nonexistent hook fails',
);

my $new_hooks = [ sub {$count--}, sub {$count--}, sub {$count--} ];
$f->replace_hooks('foobar',$new_hooks);
$f->execute_hooks('foobar');
is $count, -2, 'replaced hooks were installed and executed';
