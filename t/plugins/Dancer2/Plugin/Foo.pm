package Dancer2::Plugin::Foo;
use Dancer2;
use Dancer2::Plugin;
register foo => sub { 123 };
register_plugin;
1;
