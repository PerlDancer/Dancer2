use strict;
use warnings;

use Test::More tests => 6;
use Test::Deep;
use Scalar::Util qw/ refaddr /;

{
    package Dancer2::Plugin::Foo;
    use Dancer2::Plugin2;
}

{
    package Dancer2::Plugin::Bar;
    use Dancer2::Plugin2;
}

{
    package Dancer2::Plugin::Baz;
    use Dancer2::Plugin2;
}

{
    package MyApp;
    use Dancer2;
}

my $app = MyApp::app();

my $plugin = $app->with_plugin('Foo');

isa_ok $plugin => 'Dancer2::Plugin2';

cmp_deeply $app->plugins => [ 
    isa('Dancer2::Plugin::Foo') 
], "app has the plugin";

my $same_plugin =  $app->with_plugin('Foo');

is refaddr $same_plugin => refaddr $plugin,
    "plugin is not redefined";

cmp_deeply $app->plugins => [ 
    isa('Dancer2::Plugin::Foo') 
], "still a single plugin";

subtest "adding plugin Bar" => sub {
    my $plugin = $app->with_plugin('Bar');

    isa_ok $plugin => 'Dancer2::Plugin2';

    cmp_deeply $app->plugins => [ 
        isa('Dancer2::Plugin::Foo'),
        isa('Dancer2::Plugin::Bar') 
    ], "app has both plugins";
};

subtest "adding as an object" => sub {
    my $plugin = Dancer2::Plugin::Baz->new( app => $app );
    my $p = $app->with_plugin($plugin);

    is refaddr $p => refaddr $plugin, "it's the same";

    cmp_deeply $app->plugins => [ 
        isa('Dancer2::Plugin::Foo'),
        isa('Dancer2::Plugin::Bar'),
        isa('Dancer2::Plugin::Baz') 
    ], "app has all 3 plugins";
};
