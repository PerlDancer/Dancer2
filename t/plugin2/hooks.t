use strict;
use warnings;

use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package Dancer2::Plugin::FooDetector;

    use Dancer2::Plugin;

    plugin_hooks 'foo';


    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_hook(
            Dancer2::Core::Hook->new(
                name => 'after',
                code => sub {
                    $plugin->app->execute_hook( 'plugin.foodetector.foo' )
                        if $_[0]->content =~ /foo/;
                }
        ) );
    }
}

{
    package PoC;

    use Dancer2;

    use Dancer2::Plugin::FooDetector;

    my $hooked = 'nope';
    my $counter = 0;

    hook 'plugin.foodetector.foo' => sub {
        $counter++;
        $hooked = 'hooked';
    };

    get '/' => sub {
        "saying foo triggers the hook"
    };

    get 'meh' => sub { 'meh' };

    get '/hooked' => sub { $hooked };
    get '/counter' => sub { $counter };
}


my $test = Plack::Test->create( PoC->to_app );

subtest 'initial state' => sub {
    ok $test->request( GET '/meh' )->is_success;
    my $res = $test->request( GET '/hooked' );
    ok $res->is_success;
    is $res->content, 'nope';
    is $test->request( GET '/counter' )->content, '0';
};

subtest 'trigger hook' => sub {
    ok $test->request( GET '/' )->is_success;
    my $res = $test->request( GET '/hooked' );
    ok $res->is_success;
    is $res->content, 'hooked';
    is $test->request( GET '/counter' )->content, '1';
};

# GH #1018 - ensure hooks are called the correct number of times
subtest 'execute hook counting' => sub {
    ok $test->request( GET '/' )->is_success;
    my $res = $test->request( GET '/hooked' );
    ok $res->is_success;
    is $res->content, 'hooked';
    is $test->request( GET '/counter' )->content, '2';
};

