use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Plack::Test;

eval { require Test::Memory::Cycle; 1; }
    or plan skip_all => 'Test::Memory::Cycle not present';

{
    package Dancer2::Plugin::Null;
    use Dancer2::Plugin;
    plugin_keywords 'nothing';
    sub nothing {1}
}

{
    package MyApp::Cycles;
    use Dancer2;
    use Dancer2::Plugin::Null;

    set auto_page => 1;
    set serializer => 'JSON';

    get '/**' => sub {
        return { hello => 'world' };
    };
}

my $app = MyApp::Cycles->to_app;

my $runner = Dancer2->runner;
Test::Memory::Cycle::memory_cycle_ok( $runner, "runner has no memory cycles" );
Test::Memory::Cycle::memory_cycle_ok( $app, "App has no memory cycles" );

done_testing();
