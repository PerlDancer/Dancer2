use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Test::Memory::Cycle;

use Plack::Test;

{

    package MyApp::Cycles;
    use Dancer2;

    set auto_page => 1;
    set serializer => 'JSON';

    get '/**' => sub {
        return { hello => 'world' };
    };
}

my $app = MyApp::Cycles->to_app;

my $runner = Dancer2->runner;
memory_cycle_ok( $runner, "runner has no memory cycles" );
memory_cycle_ok( $app, "App has no memory cycles" );

done_testing();
