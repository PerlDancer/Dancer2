use strict;
use warnings;
use Test::More tests => 8;
use Test::Fatal;

use Dancer2::Core::Hook;

my $h =
  Dancer2::Core::Hook->new( name => 'before_template', code => sub {'BT'} );
is $h->name, 'before_template_render';
is $h->code->(), 'BT';

{

    package Foo;
    use Moo;
    with 'Dancer2::Core::Role::Hookable';
    sub supported_hooks {'foobar'}
}

my $f = Foo->new;

like(
    exception { $f->execute_hook() },
    qr{execute_hook needs a hook name},
    'execute_hook needs a hook name',
);

my $count     = 0;
my $some_hook = Dancer2::Core::Hook->new(
    name => 'foobar',
    code => sub {
        $count++;
    }
);

ok( !exception { $f->add_hook($some_hook) },
    'Supported hook can be installed',
);

like(
    exception {
        $f->add_hook(
            Dancer2::Core::Hook->new(
                name => 'unknown_hook',
                code => sub { $count++; }
            )
        );
    },
    qr{Unsupported hook 'unknown_hook'},
    'Unsupported hook cannot be installed',
);

$f->execute_hook('foobar');
is $count, 1;

like(
    exception { $f->replace_hook( 'doesnotexist', [] ) },
    qr{Hook 'doesnotexist' must be installed first},
    'Nonexistent hook fails',
);

my $new_hooks = [ sub { $count-- }, sub { $count-- }, sub { $count-- } ];
$f->replace_hook( 'foobar', $new_hooks );
$f->execute_hook('foobar');
is $count, -2, 'replaced hooks were installed and executed';
