
use strict;
use warnings;
use Test::More;

{

    package Foo;
    use Moo;
    with 'Dancer2::Core::Role::Headers';
}

my $f = Foo->new( headers => [ 'X-Foo' => 42, 'X-Bar' => 43 ] );
is $f->header('x-foo'), 42, "header can be read with lowercase";
is $f->header('X-Foo'), 42, "header can be read with original name";

$f->header( 'x-baz' => 44 );
is $f->header('x-baz'), 44, "new header is created";

$f->header( 'X-Foo' => 777 );
is $f->header('X-Foo'), 777, "existing header is replaced";

$f->push_header( 'X-Foo' => 888 );
is $f->header('X-Foo'), '777, 888', "push_header appends a value";

done_testing;
