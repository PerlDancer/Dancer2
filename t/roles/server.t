use Test::More;
use Test::Fatal;

use strict;
use warnings;

{

    package Foo;
    use Moo;
    with 'Dancer2::Core::Role::Server';

    sub _build_name {'foo'}
}

my $s;

like( exception { $s = Foo->new }, qr{required.*host}, "host is mandatory", );

like(
    exception { $s = Foo->new( host => 'localhost' ) },
    qr{required.*port}, "port is mandatory",
);

my $runner = Dancer2::Core::Runner->new( caller => $0 );
$s = Foo->new( host => 'localhost', port => 3000, runner => $runner );
my $app = Dancer2::Core::App->new( name => 'main' );

$s->register_application($app);

is $s->apps->[0]->name, 'main', 'app has been registered';
isa_ok $s->dispatcher, 'Dancer2::Core::Dispatcher';

my $psgi_app = $s->psgi_app;
is ref($psgi_app), 'CODE', 'got a subroutine when asked for psgi_app';

done_testing,

