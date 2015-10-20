package Dancer2::Plugin::Bar;
use Dancer2;
use Dancer2::Plugin;
register bar => sub { 456 };
register_plugin;
1;
