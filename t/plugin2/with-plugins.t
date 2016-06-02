use strict;
use warnings;

use Test::More tests => 8;
use Scalar::Util qw/ refaddr /;

{
    package Dancer2::Plugin::Foo;
    use Dancer2::Plugin;
}

{
    package Dancer2::Plugin::Bar;
    use Dancer2::Plugin;
}

{
    package Dancer2::Plugin::Baz;
    use Dancer2::Plugin;
}

{
    package MyApp;
    use Dancer2;
}

my $app = MyApp::app();

my $plugin = $app->with_plugin('Foo');

isa_ok $plugin => 'Dancer2::Plugin';

cmp_ok @{ $app->plugins }, '==', 1, "app has one plugin";
cmp_ok ref($app->plugins->[0]), 'eq', 'Dancer2::Plugin::Foo' , "app has plugin Foo";

my $same_plugin =  $app->with_plugin('Foo');

is refaddr $same_plugin => refaddr $plugin,
    "plugin is not redefined";

cmp_ok @{ $app->plugins }, '==', 1, "app still has one plugin";
cmp_ok ref($app->plugins->[0]), 'eq', 'Dancer2::Plugin::Foo' , "app has plugin Foo";

subtest "adding plugin Bar" => sub {
    my $plugin = $app->with_plugin('Bar');

    isa_ok $plugin => 'Dancer2::Plugin';

    cmp_ok @{ $app->plugins }, '==', 2, "app has two plugins";

    cmp_ok ref($app->plugins->[0]), 'eq', 'Dancer2::Plugin::Foo',
      "app has plugin Foo";
    cmp_ok ref($app->plugins->[1]), 'eq', 'Dancer2::Plugin::Bar',
      "app has plugin Bar";
};

subtest "adding as an object" => sub {
    my $plugin = Dancer2::Plugin::Baz->new( app => $app );
    my $p = $app->with_plugin($plugin);

    is refaddr $p => refaddr $plugin, "it's the same";

    cmp_ok @{ $app->plugins }, '==', 3, "app has three plugins";

    cmp_ok ref($app->plugins->[0]), 'eq', 'Dancer2::Plugin::Foo',
      "app has plugin Foo";
    cmp_ok ref($app->plugins->[1]), 'eq', 'Dancer2::Plugin::Bar',
      "app has plugin Bar";
    cmp_ok ref($app->plugins->[2]), 'eq', 'Dancer2::Plugin::Baz',
      "app has plugin Baz";
};
