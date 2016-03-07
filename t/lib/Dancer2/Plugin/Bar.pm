package Dancer2::Plugin::Bar;

use strict;
use warnings;

use Dancer2::Plugin;

sub baz { 'bazbazbaz' }

sub BUILD {
    my $plugin = shift;

    $plugin->app->add_hook( Dancer2::Core::Hook->new(
            name => 'after',
            code => sub { my $resp = shift; $resp->content( $resp->content 
                    . 'plugin Bar loaded'
                ) }
        ));
}

1;


