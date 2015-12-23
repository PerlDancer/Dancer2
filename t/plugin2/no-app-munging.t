use strict;
use warnings;

use Test::More tests => 1;

{  
    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin;
}

{  
    package MyRandomModule; 
    
    use Test::More;

    sub app { fail "shouldn't try to run it" };

    use Dancer2::Plugin::Foo (); 
    
}

pass "we survived!";
