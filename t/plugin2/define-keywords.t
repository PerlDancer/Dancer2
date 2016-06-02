use strict;
use warnings;

use Test::More tests => 1;

BEGIN {  
    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin;

    push @::expected_keywords, 'foo';
    plugin_keywords foo => sub { die "unimplemented" };

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
    sub quux :PluginKeyword { die "unimplemented" };
    sub qaax :PluginKeyword(qiix) { die "unimplemented" };
    sub qoox :PluginKeyword(qox qooox) { die "unimplemented" };

}

my $plugin = Dancer2::Plugin::Foo->new( app => undef );

is_deeply [ sort keys %{ $plugin->keywords } ], 
    [ sort @::expected_keywords ], "all expected keywords";
