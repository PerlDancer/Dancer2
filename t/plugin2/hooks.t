use strict;
use warnings;

use Test::More tests => 6;
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

    hook 'plugin.foodetector.foo' => sub { 
        $hooked = 'hooked';
    };

    get '/' => sub { 
        "saying foo triggers the hook"
    };

    get 'meh' => sub { 'meh' };

    get '/hooked' => sub { $hooked };
}


my $test = Plack::Test->create( PoC->to_app );

ok $test->request( GET '/meh' )->is_success;
my $res = $test->request( GET '/hooked' );
ok $res->is_success;
is $res->content, 'nope';

ok $test->request( GET '/' )->is_success;
$res = $test->request( GET '/hooked' );
ok $res->is_success;
is $res->content, 'hooked';

