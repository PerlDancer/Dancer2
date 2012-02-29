use strict;
use warnings;
use Test::More tests => 10;
use Test::Fatal;

use Dancer::Core::Hook;

my $h = Dancer::Core::Hook->new(name => 'before_template', code => sub { 'BT' });
is $h->name, 'before_template_render';
is $h->code->(), 'BT';

{
    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Hookable';
}

my $f = Foo->new;

like(
    exception { $f->execute_hooks() },
    qr{execute_hook needs a hook name},
    'execute_hook needs a hook name',
);

like(
    exception { $f->execute_hooks('foobar') },
    qr{Hook 'foobar' does not exist},
    'Hook does not exist',
);

my $count = 0;
my $some_hook = Dancer::Core::Hook->new(
    name => 'foobar',
    code => sub {
        $count++;
    }
);

like(
    exception { $f->add_hook($some_hook) },
    qr{Hook 'foobar' must be installed first},
    'Hook must be installed first',
);

$f->install_hooks('foobar');

like(
    exception { $f->install_hooks('foobar') },
    qr{Hook 'foobar' is already registered, please use another name},
    'Hook by name already registered',
);

ok(
    ! exception { $f->add_hook($some_hook) },
    'Adding hook successfully',
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
is $count, -2;
