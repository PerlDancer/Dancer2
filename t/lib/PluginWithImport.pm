package t::lib::PluginWithImport;

#ABSTRACT: a plugin that implement its own import method

=head1 DESCRIPTION

In order to demonstrate that Dancer2::Plugin won't loose the original
import method of the plugin.

=cut

use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin;

my $_stuff = {};
sub stuff {$_stuff}

no warnings 'redefine';

sub import {
    my $class = shift;
    $_stuff->{$class} = 'imported';
}

register dancer_plugin_with_import_keyword => sub {
    'dancer_plugin_with_import_keyword';
};

register_plugin;

1;
