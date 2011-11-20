use strict;
use warnings;

use Test::More import => ['!pass'];
use Dancer::Plugin;

subtest 'reserved keywords' => sub {
    eval {
        register dance => sub {1};
    };
    like $@, qr/You can't use 'dance', this is a reserved keyword/,
        "Can't use Dancer's reserved keywords";

    eval {
        register '1function' => sub {1};
    };
    like $@, qr/You can't use '1function', it is an invalid name/,
     "Can't use invalid names for keywords";
};

subtest 'plugin reserved keywords' => sub {
    {
        package Foo;
        use Dancer::Plugin;

        eval { register 'foo_method' => sub { 1 } };
        Test::More::is $@, '', "can register a new keyword";
    }

    {
        package Bar;
        use Dancer::Plugin;

        eval { register 'foo_method' => sub { 1 } };
        Test::More::like $@, 
            qr{can't use foo_method, this is a keyword reserved by Foo}, 
            "cant register a keyword already registered by another plugin";
    }
};

subtest 'global and route keywords' => sub { 
    use Dancer;
    use Dancer::Test;
    use t::lib::FooPlugin;

    get '/' => sub {
        foo_wrap_request->env->{'PATH_INFO'};
    };

    foo_route;

    my $r = dancer_response( GET => '/' );
    is($r->[2][0], '/', 'route defined by a plugin');

    $r = dancer_response( GET => '/foo' );
    is($r->[2][0], 'foo', 'DSL keyword wrapped by a plugin');
};


done_testing;
