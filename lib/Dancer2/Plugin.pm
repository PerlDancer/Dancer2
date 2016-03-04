package Dancer2::Plugin;
# ABSTRACT: Extending Dancer2's DSL with plugins

use Moo::Role;
use Carp 'croak', 'carp';
use Dancer2::Core::DSL;
use Scalar::Util qw();

# singleton for storing all keywords,
# their code and the plugin they come from
my $_keywords = {};

# singleton for storing all hooks and their aliases
my $_hooks = {};

# singleton for applying code-blocks at import time
# so their code gets the callers DSL
my $_on_import = {};

sub register {
    my $plugin = caller;
    my $caller = caller(1);
    my ( $keyword, $code, $options ) = @_;
    $options ||= { is_global => 1 };

    $keyword =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
      or croak "You can't use '$keyword', it is an invalid name"
      . " (it should match ^[a-zA-Z_]+[a-zA-Z0-9_]*\$ )";

    if (grep { $_ eq $keyword }
        keys %{ Dancer2::Core::DSL->dsl_keywords }
      )
    {
        croak "You can't use '$keyword', this is a reserved keyword";
    }

    while ( my ( $plugin, $keywords ) = each %$_keywords ) {
        if ( grep { $_->[0] eq $keyword } @$keywords ) {
            croak "You can't use $keyword, "
              . "this is a keyword reserved by $plugin";
        }
    }

    $_keywords->{$plugin} ||= [];
    push @{ $_keywords->{$plugin} },
      [ $keyword, $code, $options ];
}

sub on_plugin_import(&) {
    my $code   = shift;
    my $plugin = caller;
    $_on_import->{$plugin} ||= [];
    push @{ $_on_import->{$plugin} }, $code;
}

sub register_plugin {
    my $plugin = caller;
    my $caller = caller(1);
    my %params = @_;

    # if the caller has no dsl method, we can't register the plugin
    return if !$caller->can('dsl');

    # the plugin consumes the DSL role
    Moo::Role->apply_role_to_package( $plugin, 'Dancer2::Core::Role::DSL' );

    # bind all registered keywords to the plugin
    my $dsl = $caller->dsl;
    for my $k ( @{ $_keywords->{$plugin} } ) {
        my ( $keyword, $code, $options ) = @{$k};
        {
            no strict 'refs';
            *{"${plugin}::${keyword}"} = $dsl->_apply_prototype($code, $options);
        }
    }

# create the import method of the caller (the actual plugin) in order to make it
# imports all the DSL's keyword when it's used.
    my $import = sub {
        my $plugin = shift;

        # caller(1) because our import method is wrapped, see below
        my $caller = caller(1);

        for my $k ( @{ $_keywords->{$plugin} } ) {
            my ( $keyword, $code, $options ) = @{$k};
            my $is_global = exists $options->{is_global} && $options->{is_global};
            $caller->dsl->register( $keyword, $is_global );
        }

        Moo::Role->apply_roles_to_object( $caller->dsl, $plugin );
        $caller->dsl->export_symbols_to($caller);
        $caller->dsl->dancer_app->register_plugin( $caller->dsl );

        # add hooks
        my $current_hooks = [ $caller->dsl->supported_hooks ];
        my $current_aliases = $caller->dsl->hook_aliases;
        for my $h ( keys %{ $_hooks->{$plugin} } ) {
            push @$current_hooks, $h;
            $current_aliases->{ $_hooks->{$plugin}->{$h} } = $h;
			# If the hooks atttribute has already been constructed,
			# add an entry so has_hook() finds these hooks.
            $caller->dsl->hooks->{$h} = []
                if ! exists $caller->dsl->hooks->{$h};
        }
        my $target = ref $caller->dsl;
        {
            no strict 'refs';
            no warnings 'redefine';
            *{"${target}::supported_hooks"} = sub {@$current_hooks};
            *{"${target}::hook_aliases"}    = sub {$current_aliases};
        }

        for my $sub ( @{ $_on_import->{$plugin} } ) {
            $sub->( $caller->dsl );
        }
    };
    my $app_caller = caller();
    {
        no strict 'refs';
        no warnings 'redefine';
        my $original_import = *{"${app_caller}::import"}{CODE};
        $original_import ||= sub { };
        *{"${app_caller}::import"} = sub {
            $original_import->(@_);
            $import->(@_);
        };
    }
    return 1;    #as in D1

    # The plugin is ready now.
}

sub plugin_args {@_}

sub plugin_setting {
    my $plugin = caller;
    my $dsl    = _get_dsl()
        or croak 'No DSL object found';

    ( my $plugin_name = $plugin ) =~ s/Dancer2::Plugin:://;

    return $dsl->app->config->{'plugins'}->{$plugin_name} ||= {};
}

sub register_hook {
    my (@hooks) = @_;

    my $caller = caller;
    my $plugin = $caller;

    $plugin =~ s/^Dancer2::Plugin:://;
    $plugin =~ s/::/_/g;

    my $base_name = "plugin." . lc($plugin);
    for my $hook (@hooks) {
        my $hook_name = "${base_name}.$hook";
        $_hooks->{$caller}->{$hook_name} = $hook;
    }
}

sub execute_hook {
    my $position = shift;
    my $dsl      = _get_dsl();
    croak "No DSL object found" if !defined $dsl;
    $dsl->execute_hook( $position, @_ );
}

# private

my $dsl_deprecation_wrapper = 0;
sub import {
    my $class  = shift;
    my $plugin = caller;

    # First, export Dancer2::Plugins symbols
    my @export = qw(
      execute_hook
      register_hook
      register_plugin
      register
      on_plugin_import
      plugin_setting
      plugin_args
    );

    for my $symbol (@export) {
        no strict 'refs';
        *{"${plugin}::${symbol}"} = *{"Dancer2::Plugin::${symbol}"};
    }

    my $dsl = _get_dsl();
    return if !defined $dsl;

# DEPRECATION NOTICE
# We expect plugin to be written with a $dsl object now, so
# this keywords will trigger a deprecation notice and will be removed in a later
# version of Dancer2.

 # Support for Dancer 1 syntax for plugin.
 # Then, compile Dancer 2's DSL keywords into self-contained keywords for the
 # plugin (actually, we call all the symbols by giving them $caller->dsl as
 # their first argument).
 # These modified versions of the DSL are then exported in the namespace of the
 # plugin.
    if (! grep { $_ eq ':no_dsl' } @_) {
        for my $symbol ( keys %{ $dsl->keywords } ) {

            # get the original symbol from the real DSL
            no strict 'refs';
            no warnings qw( redefine once );
            my $code = *{"Dancer2::Core::DSL::$symbol"}{CODE};

            # compile it with $caller->dsl
            my $compiled = sub {
                carp
                  "DEPRECATED: $plugin calls '$symbol' instead of '\$dsl->$symbol'.";
                $code->( $dsl, @_ );
            };

            if ( $symbol eq 'dsl' ) {
                $compiled = sub { $dsl };
                $dsl_deprecation_wrapper = $compiled
            }

            # Bind the newly compiled symbol to the caller's namespace.
            # As this may redefine a symbol, ensure the new coderef has
            # the same prototype signature.
            my $existing = *{"${plugin}::${symbol}"};
            my $prototype = prototype \&$existing;
            *{"${plugin}::${symbol}"} = Scalar::Util::set_prototype( \&$compiled, $prototype );
        }
    }

    # Finally, make sure our caller becomes a Moo::Role
    # Perl 5.8.5+ mandatory for that trick
    @_ = ('Moo::Role');
    goto &Moo::Role::import;
}

sub _get_dsl {
    my $dsl;
    my $deep = 2;
    while ( my $caller = caller( $deep++ ) ) {
        my $caller_dsl = $caller->can('dsl');
        next if ! $caller_dsl || $caller_dsl == $dsl_deprecation_wrapper;
        $dsl = $caller->dsl;
        last if defined $dsl && length( ref($dsl) );
    }

    return $dsl;
}

1;

__END__

=head1 DESCRIPTION

You can extend Dancer2 by writing your own plugin. A plugin is a module that
exports a bunch of symbols to the current namespace (the caller will see all
the symbols defined via C<register>).

Note that you have to C<use> the plugin wherever you want to use its symbols.
For instance, if you have Webapp::App1 and Webapp::App2, both loaded from your
main application, they both need to C<use FooPlugin> if they want to use the
symbols exported by C<FooPlugin>.

For a more gentle introduction to Dancer2 plugins, see L<Dancer2::Plugins>.

=method register

    register 'my_keyword' => sub { ... } => \%options;

Allows the plugin to define a keyword that will be exported to the caller's
namespace.

The first argument is the symbol name, the second one the coderef to execute
when the symbol is called.

The coderef receives as its first argument the Dancer2::Core::DSL object.

Plugins B<must> use the DSL object to access application components and work
with them directly.

    sub {
        my $dsl = shift;
        my @args = @_;

        my $app     = $dsl->app;
        my $request = $app->request;

        if ( $app->session->read('logged_in') ) {
            ...
        }
    };

As an optional third argument, it's possible to give a hash ref to C<register>
in order to set some options.

The option C<is_global> (boolean) is used to declare a global/non-global keyword
(by default all keywords are global). A non-global keyword must be called from
within a route handler (eg: C<session> or C<param>) whereas a global one can be
called from everywhere (eg: C<dancer_version> or C<setting>).

    register my_symbol_to_export => sub {
        # ... some code
    }, { is_global => 1} ;

=method on_plugin_import

Allows the plugin to take action each time it is imported.
It is prototyped to take a single code block argument, which will be called
with the DSL object of the package importing it.

For example, here is a way to install a hook in the importing app:

    on_plugin_import {
        my $dsl = shift;
        $dsl->app->add_hook(
            Dancer2::Core::Hook->new(
                name => 'before',
                code => sub { ... },
            )
        );
    };

=method register_plugin

A Dancer2 plugin must end with this statement. This lets the plugin register all
the symbols defined with C<register> as exported symbols:

    register_plugin;

Register_plugin returns 1 on success and undef if it fails.

=method plugin_args

Simple method to retrieve the parameters or arguments passed to a
plugin-defined keyword. Although not relevant for Dancer 1 only, or
Dancer 2 only, plugins, it is useful for universal plugins.

  register foo => sub {
     my ($dsl, @args) = plugin_args(@_);
     ...
  }

Note that Dancer 1 will return undef as the DSL object.

=method plugin_setting

If C<plugin_setting> is called inside a plugin, the appropriate configuration
will be returned. The C<plugin_name> should be the name of the package, or,
if the plugin name is under the B<Dancer2::Plugin::> namespace (which is
recommended), the remaining part of the plugin name.

Configuration for plugin should be structured like this in the config.yml of
the application:

  plugins:
    plugin_name:
      key: value

Enclose the remaining part in quotes if it contains ::, e.g.
for B<Dancer2::Plugin::Foo::Bar>, use:

  plugins:
    "Foo::Bar":
      key: value

=method register_hook

Allows a plugin to declare a list of supported hooks. Any hook declared like so
can be executed by the plugin with C<execute_hook>.

    register_hook 'foo';
    register_hook 'foo', 'bar', 'baz';

=method execute_hook

Allows a plugin to execute the hooks attached at the given position

    $dsl->execute_hook( 'some_hook' );

Arguments can be passed which will be received by handlers attached to that
hook:

    $dsl->execute_hook( 'some_hook', @some_args );

The hook must have been registered by the plugin first, with C<register_hook>.

=head1 EXAMPLE PLUGIN

The following code is a dummy plugin that provides a keyword 'logout' that
destroys the current session and redirects to a new URL specified in
the config file as C<after_logout>.

  package Dancer2::Plugin::Logout;
  use Dancer2::Plugin;

  register logout => sub {
    my $dsl  = shift;
    my $app  = $dsl->app;
    my $conf = plugin_setting();

    $app->destroy_session;

    return $app->redirect( $conf->{after_logout} );
  };

  register_plugin;
  1;

And in your application:

    package My::Webapp;

    use Dancer2;
    use Dancer2::Plugin::Logout;

    get '/logout' => sub { logout };

=cut
