use strict;
use warnings;

use Test::More import => ['!pass'];
use Dancer::Test;
use Test::Fatal;

subtest 'reserved keywords' => sub {
    use Dancer::Plugin;
    like(
        exception {
            register dance => sub {1}
        },
        qr/You can't use 'dance', this is a reserved keyword/,
        "Can't use Dancer's reserved keywords",
    );

    like(
        exception {
            register '1function' => sub {1}
        },
        qr/You can't use '1function', it is an invalid name/,
        "Can't use invalid names for keywords",
    );
};

subtest 'plugin reserved keywords' => sub {
    {

        package Foo;
        use Dancer::Plugin;

        Test::More::is(
            Test::Fatal::exception {
                register 'foo_method' => sub {1}
            },
            undef,
            "can register a new keyword",
        );
    }

    {

        package Bar;
        use Dancer::Plugin;

        Test::More::like(
            Test::Fatal::exception {
                register 'foo_method' => sub {1}
            },
            qr{can't use foo_method, this is a keyword reserved by Foo},
            "cant register a keyword already registered by another plugin",
        );
    }
};

subtest 'plugin version' => sub {

    package Foo;
    our $VERSION = '1.034';
    use Dancer;
    use Dancer::Plugin;

    eval {register_plugin};
    Test::More::like $@, qr{Foo 1.034 does not support Dancer 2};
};


done_testing;
