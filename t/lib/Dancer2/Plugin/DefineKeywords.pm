package Dancer2::Plugin::DefineKeywords;

use Dancer2::Plugin;

push @::expected_keywords, 'foo';
plugin_keywords foo => sub { 'foo' };

push @::expected_keywords, 'bar';
has bar => (
    is => 'ro',
    plugin_keyword => 1,
    default => sub { 'bar' },
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
sub quux :PluginKeyword { 'quux' };
sub qaax :PluginKeyword(qiix) { die "unimplemented" };
sub qoox :PluginKeyword(qox qooox) { die "unimplemented" };

1;
