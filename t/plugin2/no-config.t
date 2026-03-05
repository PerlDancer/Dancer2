use strict;
use warnings;

use Test::More tests => 1;

BEGIN {  
    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin;

        has bar => (
            is => 'ro',
            from_config => 1,
        );

        has baz => (
            is => 'ro',
            default => sub { $_[0]->config->{baz} },
        );

        plugin_keywords qw/ bar baz /;

}

{  
    package MyApp; 

    use Dancer2;
    use Dancer2::Plugin::Foo;

    bar();

    baz();
    
}

pass "we survived bar() and baz()";

