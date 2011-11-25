package Dancer::Plugin;
use Moo::Role;
use Carp 'croak';
use Dancer::Core::DSL;

sub import {
    my $class = shift;
    my $plugin = caller;


    # First, export Dancer::Plugins symbols
    my @export = qw(
        register_plugin
        register
    );
    for my $symbol (@export) {
        no strict 'refs';
        *{"${plugin}::${symbol}"} = *{"Dancer::Plugin::${symbol}"};
    }

    # Support for Dancer 1 syntax for plugin.
    # Then, compile Dancer's DSL keywords into self-contained keywords for the
    # plugin (actually, we call all the symbols by giving them $caller->dsl as
    # their first argument).
    # These modified versions of the DSL are then exported in the namespace of the
    # plugin.
    for my $symbol (Dancer::Core::DSL->dsl_keywords_as_list) {

        # get the original symbol from the real DSL
        no strict 'refs';
        my $code = *{"Dancer::Core::DSL::$symbol"}{CODE};

        # compile it with $caller->dsl (we cant use a closure on the $caller now
        # since we're at import time, it's not already ready).
        my $compiled = sub {
            my $caller = caller(2); # the app that uses the plugin
            my $dsl = $caller->dsl;
            $code->($dsl, @_);
        };

        # bind the newly compiled symbol to the caller's namespace.
        *{"${plugin}::${symbol}"} = $compiled;
    }
    
    # Finally, make sure our caller becomes a Moo::Role
    # Perl 5.8.5+ mandatory for that trick
    @_ = ('Moo::Role');
    goto &Moo::Role::import
}

# registry for storing all keywords, their code and the plugin they come from
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

sub register_plugin {
    my $plugin = caller;
    my $caller = caller(1);
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
}

1;

__END__
use strict;
use warnings;
use Carp;

use Dancer;
use Dancer::Core::DSL;
use base 'Exporter';
use vars qw(@EXPORT);

@EXPORT = qw(
  register
  register_plugin
  plugin_settings
  plugin_setting
);

# TODO : add_hook (what is it supposed to do?)

sub register($&);

my @_keywords = Dancer::Core::DSL->_keyword_list;
my $_keywords = {};

sub plugin_settings {
    my $plugin_orig_name = caller();
    (my $plugin_name = $plugin_orig_name) =~ s/Dancer::Plugin:://;

    my $caller = caller;
    my $app = $caller->dancer_app;
    return $app->config->{'plugins'}->{$plugin_name} ||= {};
}

sub plugin_setting { goto &plugin_settings }

sub register($&) {
    my ($keyword, $code) = @_;
    my $plugin_name = caller();

    $keyword =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/
      or croak "You can't use '$keyword', it is an invalid name"
        . " (it should match ^[a-zA-Z_]+[a-zA-Z0-9_]*$ )";

    if (
        grep { $_ eq $keyword } 
        map  { s/^(?:\$|%|&|@|\*)//; $_ } 
        (@_keywords)
    ) {
        croak "You can't use '$keyword', this is a reserved keyword";
    }
    while (my ($plugin, $keywords) = each %$_keywords) {
        if (grep { $_->[0] eq $keyword } @$keywords) {
            croak "You can't use $keyword, "
                . "this is a keyword reserved by $plugin";
        }
    }

    $_keywords->{$plugin_name} ||= [];
    push @{$_keywords->{$plugin_name}}, [$keyword => $code];
}

sub register_plugin {
    my ($application) = shift || caller(1);
    my ($plugin) = caller();

    my @symbols = set_plugin_symbols($plugin);
    {
        no strict 'refs';
        # tried to use unshift, but it yields an undef warning on $plugin (perl v5.12.1)
        @{"${plugin}::ISA"} = ('Exporter', 'Dancer::Plugin', @{"${plugin}::ISA"});
        push @{"${plugin}::EXPORT"}, @symbols;
    }
    return 1;
}

sub set_plugin_symbols {
    my ($plugin) = @_;

    for my $keyword (@{$_keywords->{$plugin}}) {
        my ($name, $code) = @$keyword;
        {
            no strict 'refs';
            *{"${plugin}::${name}"} = $code;
        }
    }
    return map { $_->[0] } @{$_keywords->{$plugin}};
}

1;
__END__

=pod

=head1 NAME

Dancer::Plugin - helper for writing Dancer plugins

=head1 DESCRIPTION

Create plugins for Dancer

=head1 SYNOPSIS

  package Dancer::Plugin::LinkBlocker;
  use Dancer ':syntax';
  use Dancer::Plugin;

  register block_links_from => sub {
    my $conf = plugin_setting();
    my $re = join ('|', @{$conf->{hosts}});
    before sub {
        if (request->referer && request->referer =~ /$re/) {
            status 403 || $conf->{http_code};
        }
    };
  };

  register_plugin;
  1;

And in your application:

    package My::Webapp;
    
    use Dancer ':syntax';
    use Dancer::Plugin::LinkBlocker;

    block_links_from; # this is exported by the plugin

=head1 PLUGINS

You can extend Dancer by writing your own Plugin.

A plugin is a module that exports a bunch of symbols to the current namespace
(the caller will see all the symbols defined via C<register>).

Note that you have to C<use> the plugin wherever you want to use its symbols.
For instance, if you have Webapp::App1 and Webapp::App2, both loaded from your
main application, they both need to C<use FooPlugin> if they want to use the
symbols exported by C<FooPlugin>.

=head2 METHODS

=over 4

=item B<register>

Lets you define a keyword that will be exported by the plugin.

    register my_symbol_to_export => sub {
        # ... some code 
    };

=item B<register_plugin>

A Dancer plugin must end with this statement. This lets the plugin register all
the symbols define with C<register> as exported symbols (via the L<Exporter>
module).

A Dancer plugin inherits from Dancer::Plugin and Exporter transparently.

=item B<plugin_setting>

Configuration for plugin should be structured like this in the config.yml of
the application:

  plugins:
    plugin_name:
      key: value

If C<plugin_setting> is called inside a plugin, the appropriate configuration 
will be returned. The C<plugin_name> should be the name of the package, or, 
if the plugin name is under the B<Dancer::Plugin::> namespace (which is
recommended), the remaining part of the plugin name. 

Enclose the remaining part in quotes if it contains ::, e.g.
for B<Dancer::Plugin::Foo::Bar>, use:

  plugins:
    "Foo::Bar":
      key: value

=back

=head1 AUTHORS

This module has been written by Alexis Sukrieh and others.

=head1 LICENSE

This module is free software and is published under the same
terms as Perl itself.

=cut
