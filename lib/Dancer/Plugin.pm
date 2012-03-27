package Dancer::Plugin;

# ABSTRACT: helper for extending Dancer's DSL 

=head1 DESCRIPTION

You can extend Dancer by writing your own Plugin.

A plugin is a module that exports a bunch of symbols to the current namespace
(the caller will see all the symbols defined via C<register>).

Note that you have to C<use> the plugin wherever you want to use its symbols.
For instance, if you have Webapp::App1 and Webapp::App2, both loaded from your
main application, they both need to C<use FooPlugin> if they want to use the
symbols exported by C<FooPlugin>.

=cut

use Moo::Role;
use Carp 'croak';
use Dancer::Core::DSL;

=method register

Allows the plugin to define a keyword that will be exported to the caller's
namespace.

The first argument is the symbol name, the second one the coderef to execute
when the symbol is called.

The coderef receives as its first argument the Dancer::Core::DSL object. Any
Dancer keyword wrapped by the plugin should be called with the $dsl object like
the following:

    sub {
        my $dsl = shift;
        my @args = @_;

        $dsl->some_dancer_thing;
        ...
    };

As an optional third argument, it's possible to give a hash ref to C<register>
in order to set some options. 

The option C<is_global> (boolean) is used to declare a global/non keyword (by
default all keywords are global). A non global keyword must be called from
within a route handler (eg: C<session> or C<param>) whereas a global one can be called
frome everywhere (eg: C<dancer_version> or C<setting>).

    register my_symbol_to_export => sub {
        # ... some code 
    }, { is_global => 1} ;

=cut

# singleton for storing all keywords, 
# their code and the plugin they come from
my $_keywords = {};

sub register {
    my $plugin = caller;
    my $caller = caller(1);
    my ($keyword, $code, $options) = @_;
    $options ||= { is_global => 1 };

    $keyword =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
      or croak "You can't use '$keyword', it is an invalid name"
        . " (it should match ^[a-zA-Z_]+[a-zA-Z0-9_]*$ )";

    if (
        grep { $_ eq $keyword } 
        map  { s/^(?:\$|%|&|@|\*)//; $_ } 
        ( map { $_->[0] } @{ Dancer::Core::DSL->dsl_keywords } )
    ) {
        croak "You can't use '$keyword', this is a reserved keyword";
    }

    while (my ($plugin, $keywords) = each %$_keywords) {
        if (grep { $_->[0] eq $keyword } @$keywords) {
            croak "You can't use $keyword, "
                . "this is a keyword reserved by $plugin";
        }
    }

    $_keywords->{$plugin} ||= [];
    push @{$_keywords->{$plugin}}, [
        $keyword, 
        $code, 
        $options->{is_global}
    ];
}

=method register_plugin

A Dancer plugin must end with this statement. This lets the plugin register all
the symbols defined with C<register> as exported symbols.

Since version 2, Dancer requires any plugin to declare explicitly which version
of the core it supports. This is done for safer upgrade of major versions and
allow Dancer 2 to detect legacy plugins that have not been ported to the new
core. To do so, the plugin must list the major versions of the core it supports
in an arrayref, like the following:

    # For instance, if the plugin works with Dancer 1 and 2:
    register_plugin for_versions => [ 1, 2 ]; 

    # Or if it only works for 2:
    register_plugin for_versions => [ 2 ];

If the C<for_versions> option is omitted, it dfaults to C<[ 1 ]> meaning the
plugin was written for Dancer 1 and has not been ported to Dancer 2. This is a
rather violent convention but will help a lot the migration of the ecosystem.

=cut

sub register_plugin {
    my $plugin = caller;
    my $caller = caller(1);
    my %params = @_;

    # For backward compatibility, no params means "supports only Dancer 1"
    defined $params{for_versions}
      or $params{for_versions} = [ 1 ];

    my $supported_versions = $params{for_versions} || [ 1 ];
    ref $supported_versions eq 'ARRAY'
      or croak "register_plugin must be called with an array ref";

    # if the caller has not a dsl, we cant register the plugin 
    return if ! $caller->can('dsl');
    my $dancer_version = $caller->dsl->dancer_version;
    my $plugin_version = eval "\$${plugin}::VERSION" || '??';

    # make sure the plugin is compatible with this version of Dancer
    grep /^$dancer_version$/, @{ $supported_versions }
      or croak "$plugin $plugin_version does not support Dancer $dancer_version.";


    # we have a $dsl in our caller, we can register our symbols then
    my $dsl = $caller->dsl;

    Moo::Role->apply_role_to_package($plugin, 'Dancer::Core::Role::DSL');

    for my $k (@{ $_keywords->{$plugin} }) {
        my ($keyword, $code, $is_global) = @{ $k };
        {
            no strict 'refs';
            *{"${plugin}::${keyword}"} = $code;
        }
        $dsl->register($keyword, $is_global);
    }
    
    Moo::Role->apply_roles_to_object($dsl, $plugin);
    $dsl->export_symbols_to($caller);

    $dsl->dancer_app->register_plugin($dsl);
}

=method plugin_setting

If C<plugin_setting> is called inside a plugin, the appropriate configuration 
will be returned. The C<plugin_name> should be the name of the package, or, 
if the plugin name is under the B<Dancer::Plugin::> namespace (which is
recommended), the remaining part of the plugin name. 

Configuration for plugin should be structured like this in the config.yml of
the application:

  plugins:
    plugin_name:
      key: value

Enclose the remaining part in quotes if it contains ::, e.g.
for B<Dancer::Plugin::Foo::Bar>, use:

  plugins:
    "Foo::Bar":
      key: value

=cut

sub plugin_setting {
    my $plugin = caller;
    (my $plugin_name = $plugin) =~ s/Dancer::Plugin:://;
    my $app = $plugin->dancer_app;
    return $app->config->{'plugins'}->{$plugin_name} ||= {};
}

# private

sub import {
    my $class  = shift;
    my $plugin = caller;

    # First, export Dancer::Plugins symbols
    my @export = qw(
        register_plugin
        register
        plugin_setting
    );
    for my $symbol (@export) {
        no strict 'refs';
        *{"${plugin}::${symbol}"} = *{"Dancer::Plugin::${symbol}"};
    }

    my $dsl = _get_dsl();
    return if ! defined $dsl;

    # Support for Dancer 1 syntax for plugin.
    # Then, compile Dancer's DSL keywords into self-contained keywords for the
    # plugin (actually, we call all the symbols by giving them $caller->dsl as
    # their first argument).
    # These modified versions of the DSL are then exported in the namespace of the
    # plugin.
    for my $symbol (Dancer::Core::DSL->dsl_keywords_as_list) {

        # get the original symbol from the real DSL
        no strict 'refs';
        no warnings 'redefine';
        my $code = *{"Dancer::Core::DSL::$symbol"}{CODE};

        # compile it with $caller->dsl
        my $compiled = sub { $code->($dsl, @_) };

        # bind the newly compiled symbol to the caller's namespace.
        *{"${plugin}::${symbol}"} = $compiled;
    }
    
    # Finally, make sure our caller becomes a Moo::Role
    # Perl 5.8.5+ mandatory for that trick
    @_ = ('Moo::Role');
    goto &Moo::Role::import
}

sub _get_dsl {
    my $dsl;
    my $deep = 2;
    while (my $caller = caller($deep++)) {
        $dsl = $caller->dsl if $caller->can('dsl');
        last if defined $dsl;
    }

    return $dsl;
}

1;
__END__

=head1 EXAMPLE PLUGIN

The following code is a dummy plugin that provides a keyword 'block_links_from'.

  package Dancer::Plugin::LinkBlocker;
  use Dancer::Plugin;

  register block_links_from => sub {
    my $dsl = shift;

    my $conf = plugin_setting();
    my $re = join ('|', @{$conf->{hosts}});
    $dsl->before( sub {
        if ($dsl->request->referer && $dsl->request->referer =~ /$re/) {
            $dsl->status(403) || $conf->{http_code};
        }
    });
  };

  register_plugin for_versions => [ 2 ] ;

  1;

And in your application:

    package My::Webapp;
    
    use Dancer;
    use Dancer::Plugin::LinkBlocker;

    block_links_from; # this is exported by the plugin

=cut
