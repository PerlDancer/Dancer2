package Dancer2::Plugin::OnPluginImport;
use Dancer2::Plugin;

# register keyword
register some_import => sub { shift->dancer_version };

# register hook
register_hook qw(imported_plugin);

# add hook. This triggers the $dsl->hooks attribute
# to be built plugins added after this should still
# be able to register and add hooks. See #889.
on_plugin_import {
    my $dsl = shift;

    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(
            name => 'imported_plugin',
            code => sub { $dsl->dancer_version }
        )
    );
};

register_plugin;

1;
