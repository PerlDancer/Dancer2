use strict;
use warnings;

use Test::More import => ['!pass'];
use Dancer2::Test;
use Test::Fatal;

subtest 'reserved keywords' => sub {
    use Dancer2::Plugin;
    like(
        exception {
            register dance => sub {1}
        },
        qr/You can't use 'dance', this is a reserved keyword/,
        "Can't use Dancer2's reserved keywords",
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
        use Dancer2::Plugin;

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
        use Dancer2::Plugin;

        Test::More::like(
            Test::Fatal::exception {
                register 'foo_method' => sub {1}
            },
            qr{can't use foo_method, this is a keyword reserved by Foo},
            "cant register a keyword already registered by another plugin",
        );
    }
};

subtest 'plugin_register' => sub {

    package Foo;
    our $VERSION = '1.034';
    use Dancer2;
    use Dancer2::Plugin;

    #no longer any version restrictions see GH#207, fails because no dsl
    Test::More::ok( !register_plugin for_versions => [1] );
};

done_testing;
