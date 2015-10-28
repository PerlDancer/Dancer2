use strict;
use warnings;

use Test::More tests => 1;
use Test::Deep;

BEGIN {  
    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin2;

    push @::expected_keywords, 'foo';
    plugin_keywords foo => sub { ... };

    push @::expected_keywords, 'bar';
    has bar => (
        is => 'ro',
        plugin_keyword => 1,
    );

    push @::expected_keywords, 'baz', 'bazz';
    has baz => (
        is => 'ro',
        plugin_keyword => [ qw/ baz bazz / ],
    );

    push @::expected_keywords, 'biz';
    has boz => (
        is => 'ro',
        plugin_keyword => 'biz',
    );

    push @::expected_keywords, 'quux', 'qiix', 'qox', 'qooox';
    sub quux :PluginKeyword { ... };
    sub qaax :PluginKeyword(qiix) { ... };
    sub qoox :PluginKeyword(qox qooox) { ... };

}

my $plugin = Dancer2::Plugin::Foo->new( app => undef );

cmp_deeply [ keys %{ $plugin->keywords } ], 
    bag( @::expected_keywords), "all expected keywords";
