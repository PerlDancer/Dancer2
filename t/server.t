use strict;
use warnings;
use Test::More;

{

    package Foo;
    use Moo;
    with 'Dancer::Core::Role::Server';

    sub _build_name {'Foo'}
}

use Dancer::Core::Runner;
my $runner = Dancer::Core::Runner->new(caller => __FILE__);

my $f = Foo->new(host => 'localhost', port => 3000, runner => $runner);
my $app = Dancer::Core::App->new(name => 'foo');

$f->register_application($app);
is $f->apps->[0]->name, 'foo';

is $f->host, 'localhost';
is $f->port, 3000;
ok(!$f->is_daemon);

ok(defined $f->dispatcher);
is ref($f->psgi_app), 'CODE';

done_testing;
