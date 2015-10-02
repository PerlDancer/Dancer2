use strict;
use warnings;

use Test::More tests => 6;

{  
    package Dancer2::Plugin::FooDetector;

    use Dancer2::Plugin2;

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


use Test::WWW::Mechanize::PSGI;

 my $mech = Test::WWW::Mechanize::PSGI->new(
          app =>  PoC->to_app
      );

$mech->get_ok( '/meh' );
$mech->get_ok( '/hooked' );
$mech->content_is( 'nope' );

$mech->get_ok( '/' );
$mech->get_ok( '/hooked' );
$mech->content_is( 'hooked' );
