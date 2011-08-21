use Test::More;

use strict;
use warnings;

{
    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Server';

    sub name { "foo" }
}

my $s;

eval { $s = Foo->new };
like $@, qr{required.*host}, "host is mandatory";

eval { $s = Foo->new(host => 'localhost') };
like $@, qr{required.*port}, "port is mandatory";

$s = Foo->new(host => 'localhost', port => 3000);
my $app = Dancer::Core::App->new(name => 'main');

$s->register_application($app);

is $s->apps->[0]->name, 'main', 'app has been registered';
isa_ok $s->dispatcher, 'Dancer::Core::Dispatcher';

my $psgi_app = $s->psgi_app;
is ref($psgi_app), 'CODE', 'got a subroutine when asked for psgi_app';

done_testing,

