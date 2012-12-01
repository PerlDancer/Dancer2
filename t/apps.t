use strict;
use warnings;

use Test::More tests => 1;

use Dancer app => 'MyApp';

{
    package Foo;

    use Dancer app => 'MyApp';

    get '/foo' => sub { 'foo' };
}

{
    package Bar;

    use Dancer app => 'SubApp';

    get '/bar' => sub { 'bar' };
}

is @{runner()->server->apps} => 2, "2 apps";

