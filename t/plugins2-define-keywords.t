use strict;
use warnings;

use Test::More tests => 9;

BEGIN {  
    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin2;

    plugin_keywords foo => sub { ... };

    has bar => (
        is => 'ro',
        plugin_keyword => 1,
    );

    has baz => (
        is => 'ro',
        plugin_keyword => [ qw/ baz bazz / ],
    );

    has boz => (
        is => 'ro',
        plugin_keyword => 'biz',
    );

    sub quux :PluginKeyword { ... };
    sub qaax :PluginKeyword(qiix) { ... };
    sub qoox :PluginKeyword(qox qooox) { ... };

}

my $plugin = Dancer2::Plugin::Foo->new( app => undef );

ok $plugin->keywords->{$_}, $_ for qw/ foo bar quux baz bazz biz qiix qox qooox /;

