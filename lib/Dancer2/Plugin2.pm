package Dancer2::Plugin2;
# ABSTRACT: base class for Dancer2 plugins

use strict;
use warnings;

use Moo;
use Carp;
use List::Util qw/ reduce /;
use Attribute::Handlers;

extends 'Exporter::Tiny';

with 'Dancer2::Core::Role::Hookable';

has app => (
    is       => 'ro',
    required => 1,
);

has config => (
    is => 'ro',
    lazy => 1,
    default => sub { 
        my $self = shift;
        my $config = $self->app->config;
        my $package = ref $self; # TODO
        $package =~ s/Dancer2::Plugin:://;
        $config->{plugins}{$package} || {};
    },
);

my $_keywords = {};
sub keywords { $_keywords }

has '+hooks' => (
    default => sub {
        my $plugin = shift;
        my $name = 'plugin.' . lc ref $plugin;
        $name =~ s/Dancer2::Plugin:://i;
        $name =~ s/::/_/g;

        +{ 
            map { join( '.', $name, $_ ) => [] }
                @{ $plugin->ClassHooks }  
        };
    },
);

sub add_hooks {
    my $class = shift;
    push @{ $class->ClassHooks }, @_;
}

sub execute_plugin_hook {
    my ( $self, $name, @args ) = @_;
    my $plugin_class = ref $self;

    $plugin_class =~ s/^Dancer2::Plugin:://
        or croak "Cannot call plugin hook ($name) from outside plugin";

    my $full_name = 'plugin.' . lc($plugin_class) . ".$name";
    $full_name =~ s/::/_/g;

    $self->app->execute_hook( $full_name, @args );
}

# both functions are there for D2::Core::Role::Hookable
# back-compatibility. Aren't used
sub supported_hooks { [] }
sub hook_aliases    { $_[0]->{'hook_aliases'} ||= {} }

### has() STUFF  ######################################## 

# our wrapping around Moo::has, done to be able to intercept
# both 'from_config' and 'plugin_keyword'
sub _p2_has {
    my $class = shift;
    $class->_p2_has_from_config( $class->_p2_has_keyword( @_ ) );
};

sub _p2_has_from_config {
    my( $class, $name, %args ) = @_;

    my $config_name = delete $args{'from_config'} 
        or return ( $name, %args );

    $args{lazy} = 1;

    if ( ref $config_name eq 'CODE' ) {
        $args{default} ||= $config_name;
        $config_name = 1;
    }

    $config_name = $name if $config_name eq '1';
    my $orig_default = $args{default} || sub{}; 
    $args{default} = sub {
        my $plugin = shift;
        my $value = reduce { eval { $a->{$b} } } $plugin->config, split '\.', $config_name;
        return defined $value ? $value: $orig_default->($plugin);
    };

    return $name => %args;
}

sub _p2_has_keyword {
    my( $class, $name, %args ) = @_;

    if( my $keyword = delete $args{plugin_keyword} ) {

        $keyword = $name if $keyword eq '1';

        $class->keywords->{$_} = sub { (shift)->$name(@_) }
            for ref $keyword ? @$keyword : $keyword;
    }

    return $name => %args;
}

### ATTRIBUTE HANDLER STUFF ######################################## 

# :PluginKeyword shenanigans

sub PluginKeyword :ATTR(CODE) {
    my( $class, $sym_ref, $code, undef, $args ) = @_;
    my $func_name = *{$sym_ref}{NAME};
    
    $args = join '', @$args if ref $args eq 'ARRAY';

    for my $name ( split ' ', $args || $func_name ) {
        $class->keywords->{$name} = $code;
    }

}

## EXPORT STUFF ##############################################################

# this @EXPORT will only be taken
# into account when we do a 'use Dancer2::Plugin2'
# I.e., it'll only do its magic for the 
# plugins themselves, not when they are
# called
our @EXPORT = qw/ :plugin /;

sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    my $caller = $global->{into};

    return _exporter_plugin($caller)
        if $name eq 'plugin';

    return _exporter_app($class,$caller,$global)
        if $name eq 'app' and $caller->can('app');

    return;

}

# plugin has been called within a D2 app. Modify
# the app and export keywords
sub _exporter_app {
    my( $class, $caller, $global ) = @_;

    my $app = eval "${caller}::app()" or return;

    return unless $app->can('with_plugin');

    ( my $short = $class ) =~ s/Dancer2::Plugin:://;

    my $plugin = $app->with_plugin( $short );
    $global->{plugin} = $plugin;

    return unless $class->can('keywords');

    # deprecated backwards compat: on_plugin_import()
    $_->($plugin) for @{ $plugin->_DANCER2_IMPORT_TIME_SUBS() };

    # Add our hooks to the app, so they're recognized
    # this is for compatibility so you can call execute_hook()
    # without the fully qualified plugin name.
    # The reason we need to do this here instead of when adding a
    # hook is because we need to register in the app, and only now it
    # exists.
    # This adds a caveat that two plugins cannot register
    # the same hook name, but that will be deprecated anyway.
    {;
        foreach my $hook ( @{ $plugin->ClassHooks } ) {
            my $full_name = 'plugin.' . lc($class) . ".$hook";
            $full_name =~ s/Dancer2::Plugin:://i;
            $full_name =~ s/::/_/g;
            $plugin->hook_aliases->{$hook} = $full_name;
        }
    }

    map { [ $_ =>  {plugin => $plugin}  ] } keys %{ $plugin->keywords };
}

# turns the caller namespace into
# a D2P2 class, with exported keywords
sub _exporter_plugin {
    my $caller = shift;

    eval <<"END";
        { 
            package $caller; 
            use Moo; 
            use Carp ();
            use Attribute::Handlers;

            extends 'Dancer2::Plugin2'; 

            our \@EXPORT = ( ':app' ); 

            around has => sub {
                my( \$orig, \@args ) = \@_;
                \$orig->( ${caller}->_p2_has( \@args) );
            };

            sub PluginKeyword :ATTR(CODE) {
                goto &Dancer2::Plugin2::PluginKeyword;
            }

            sub execute_plugin_hook {
                goto &Dancer2::Plugin2::execute_plugin_hook;
            }

            my \$_keywords = {};
            sub keywords { \$_keywords }

            my \$_ClassHooks = [];
            sub ClassHooks { \$_ClassHooks }

            # deprecated backwards compat
            sub register_plugin {1}

            sub register {
                my ( \$keyword, \$sub ) = \@_;
                \$_keywords->{\$keyword} = \$sub;

                # Exporter::Tiny doesn't seem to generate the subs
                # in the caller properly, so we have to do it manually
                {
                    no strict 'refs';
                    *{"${caller}::\$keyword"} = \$sub;
                }
            }

            my \@_DANCER2_IMPORT_TIME_SUBS;
            sub _DANCER2_IMPORT_TIME_SUBS {\\\@_DANCER2_IMPORT_TIME_SUBS}
            sub on_plugin_import (&) {
                push \@_DANCER2_IMPORT_TIME_SUBS, \$_[0];
            }

            sub register_hook { goto &plugin_hooks }

            sub dancer_app {
                Carp::carp "Plugin DSL method 'dancer_app' is deprecated. "
                         . "Use 'app' instead'.\n";

                \$_[0]->app;
            }

            sub request {
                Carp::carp "Plugin DSL method 'request' is deprecated. "
                         . "Use 'app->request' instead'.\n";

                \$_[0]->app->request;
            }
        }
END

    die $@ if $@;

    return map { [ $_ => { class => $caller } ] } 
               qw/ plugin_keywords plugin_hooks /;
}

sub _exporter_expand_sub {
    my( $plugin, $name, $args, $global ) = @_;
    my $class = $args->{class};

    return _exported_plugin_keywords($plugin,$class)
        if $name eq 'plugin_keywords';

    return _exported_plugin_hooks($class) 
        if $name eq 'plugin_hooks';

    # otherwise, we're exporting a keyword

    my $p = $args->{plugin};
    my $sub = $p->keywords->{$name};
    return $name => sub(@) { $sub->($p,@_) };
}

# define the exported 'plugin_keywords'
sub _exported_plugin_keywords{
    my( $plugin, $class ) = @_;

    return plugin_keywords => sub(@) {
        while( my $name = shift @_ ) {
            my $sub = ref $_[0] eq 'CODE' 
                ? shift @_ 
                : eval '\&'.$class."::" . ( ref $name ? $name->[0] : $name );
            $class->keywords->{$_} = $sub for ref $name ? @$name : $name;
        }
    }
}

sub _exported_plugin_hooks {
    my $class = shift;
    return plugin_hooks => sub (@) { $class->add_hooks(@_) }
}

1;

__END__

=head1 SYNOPSIS

The plugin itself:


    package Dancer2::Plugin::Polite;

    use strict;
    use warnings;

    use Dancer2::Plugin2;

    has smiley => (
        is => 'ro',
        default => sub {
            $_[0]->config->{smiley} || ':-)'
        }
    );

    plugin_keywords 'add_smileys';

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_hook( Dancer2::Core::Hook->new(
            name => 'after',
            code => sub { $_[0]->content( $_[0]->content . " ... please?" ) }
        ));

        $plugin->app->add_route(
            method => 'get',
            regexp => '/goodbye',
            code   => sub { 
                my $app = shift;
                'farewell, ' . $app->request->params->{name};
            },
        );

    }

    sub add_smileys {
        my( $plugin, $text ) = @_;

        $text =~ s/ (?<= \. ) / $plugin->smiley /xeg;

        return $text;
    }

    1;

then to load into the app:


    package MyApp;

    use strict;
    use warnings;

    use Dancer2;

    BEGIN { # would usually be in config.yml
        set plugins => {
            Polite => {
                smiley => '8-D',
            },
        };
    }

    use Dancer2::Plugin::Polite;

    get '/' => sub {
        add_smileys( 'make me a sandwich.' );
    };

    1;


=head1 DESCRIPTION

This is an alternate plugin basis for Dancer2.

=head2 Writing the plugin

=head3 C<use Dancer2::Plugin2>

The plugin must begin with

    use Dancer2::Plugin2;

which will turn the package into a L<Moo> class that inherits from L<Dancer2::Plugin2>. The base class provides the plugin with 
two attributes: C<app>, which is populated with the Dancer2 app object for which
the plugin is being initialized for, and C<config> which holds the plugin 
section of the application configuration. 

=head3 Modifying the app at building time

If the plugin needs to tinker with the application -- add routes or hooks, for example --
it can do so within its C<BUILD()> function.

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_route( ... );
    }

=head3 Adding keywords

=head4 Via C<plugin_keywords>

Keywords that the plugin wishes to export to the Dancer2 app can be defined via the C<plugin_keywords> keyword:

    plugin_keywords qw/ 
        add_smileys 
        add_sad_kitten  
    /;

Each of the keyword will resolve to the class method of the same name. When invoked as keyword, it'll be passed
the plugin object as its first argument.

    sub add_smileys {
        my( $plugin, $text ) = @_;

        return join ' ', $text, $plugin->smiley;
    }

    # and then in the app

    get '/' => sub {
        add_smileys( "Hi there!" );
    };

You can also pass the functions directly to C<plugin_keywords>.

    plugin_keywords 
        add_smileys => sub { 
            my( $plugin, $text ) = @_;

            $text =~ s/ (?<= \. ) / $plugin->smiley /xeg;

            return $text;
        },
        add_sad_kitten => sub { ... };

Or a mix of both styles. We're easy that way:

    plugin_keywords 
        add_smileys => sub { 
            my( $plugin, $text ) = @_;

            $text =~ s/ (?<= \. ) / $plugin->smiley /xeg;

            return $text;
        },
        'add_sad_kitten';

    sub add_sad_kitten {
        ...;
    }

If you want several keywords to be synonyms calling the same 
function, you can list them in an arrayref. The first 
function of the list is taken to be the "real" method to
link to the keywords.

    plugin_keywords [qw/ add_smileys add_happy_face /];

    sub add_smileys { ... }

Calls to C<plugin_keywords> are cumulative.

=head4 Via the C<:PluginKeyword> function attribute

Keywords can also be defined by adding the C<:PluginKeyword> attribute 
to the function you wish to export.

    sub foo :PluginKeyword { ... }

    sub bar :PluginKeyword( baz quux ) { ... }

    # equivalent to

    sub foo { ... }
    sub bar { ... }

    plugin_keywords 'foo', [ qw/ baz quux / ] => \&bar;

=head4 For an attribute

You can also turn an attribute of the plugin into a keyword. 

    has foo => (
        is => 'ro',
        plugin_keyword => 1,  # keyword will be 'foo'
    );

    has bar => (
        is => 'ro',
        plugin_keyword => 'quux',  # keyword will be 'quux'
    );

    has baz => (
        is => 'ro',
        plugin_keyword => [ 'baz', 'bazz' ],  # keywords will be 'baz' and 'bazz'
    );



=head3 Accessing the plugin configuration

The plugin configuration is available via the C<config()> method.

    sub BUILD {
        my $plugin = shift;

        if ( $plugin->config->{feeling_polite} ) {
            $plugin->app->add_hook( Dancer2::Core::Hook->new(
                name => 'after',
                code => sub { $_[0]->content( $_[0]->content . " ... please?" ) }
            ));
        }
    }

=head3 Getting default values from config file

Since initializing a plugin with either a default or a value passed via the configuration file, 
like

    has smiley => (
        is => 'ro',
        default => sub {
            $_[0]->config->{smiley} || ':-)'
        }
    );

C<Dancer2::Plugin2> allows for a C<from_config> key in the attribute definition.
Its value is the plugin configuration key that will be used to initialize the attribute.

If it's given the value C<1>, the name of the attribute will be taken as the configuration key.

Nested hash keys can also be refered to using a dot notation.  

If the plugin configuration has no value for the given key, the attribute default, if specified, will be honored.

If the key is given a coderef as value, it's considered to be a C<default> value combo:

    has foo => (
        is => 'ro',
        from_config => sub { 'my default' },
    );


    # equivalent to
    has foo => (
        is => 'ro',
        from_config => 'foo',
        default => sub { 'my default' },
    );

For example:

    # in config.yml

    plugins:
        Polite:
            smiley: ':-)'
            greeting:
                casual: Hi!
                formal: How do you do?


    # in the plugin
    
    has smiley => (             # will be ':-)'
        is          => 'ro',
        from_config => 1,
        default     => sub { ':-(' },
    );

    has casual_greeting => (    # will be 'Hi!'
        is          => 'ro',
        from_config => 'greeting.casual',
    );

    has apology => (            # will be 'sorry'
        is          => 'ro',
        from_config => 'apology',
        default     => sub { 'sorry' },
    )

    has closing => (            # will be 'See ya!'
        is => 'ro',
        from_config => sub { 'See ya!' },
    );

=head3 Accessing the parent Dancer app

If the plugin is instantiated within a Dancer app, it'll be
accessible via the method C<app()>.

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_route( ... );
    }


=head2 Using the plugin within the app

A plugin is loaded via

    use Dancer2::Plugin::Polite;

The plugin will assume that it's loading within a Dancer module and will 
automatically register itself against its C<app()> and export its keywords
to the local namespace. If you don't want this to happen, specify that you
don't want anything imported via empty parentheses when C<use>ing the module:

    use Dancer2::Plugin::Polite ();


=head2 Plugins using plugins

This is a (relatively) simple way for a plugin to use another plugin: 


    package Dancer2::Plugin::SourPuss;

    has polite => (
        is => 'ro',
        lazy => 1,
        default => sub {
            # if the app already has the 'Polite' plugin loaded, it'll return
            # it. If not, it'll load it in the app, and then return it.
            scalar $_[0]->app->with_plugins( 'Polite' )
        },
        handles => { 'smiley' => 'smiley' },
    );

    sub keywords { qw/ killjoy / }

    sub killjoy {
        my( $plugin, $text ) = @_;

        my $smiley = $plugin->smiley;

        $text =~ s/ $smiley />:-(/xg;

        $text;
    }

=head2 Hooks

New plugin hooks are declared via C<plugin_hooks>.

    plugin_hooks 'my_hook', 'my_other_hook';

Hooks are prefixed with C<plugin.plugin_name>. So the plugin 
C<my_hook> coming from the plugin C<Dancer2::Plugin::MyPlugin> will have the hook name
C<plugin.myplugin.my_hook>.

Hooks are executed within the plugin by calling them via the associated I<app>.

    $plugin->app->execute_plugin_hook( 'my_hook' );

You can also call any other hook if you provide the full name using the
C<execute_hook> method:

    $plugin->app->execute_hook( 'core.app.route_exception' );

Or using their alias:

    $plugin->app->execute_hook( 'on_route_exception' );

=head2 Writing Test Gotchas

=head3 Constructor for Dancer2::Plugin::Foo has been inlined and cannot be updated

You'll usually get this one because you are defining both the plugin and app 
in your test file, and the runtime creation of Moo's attributes happens after
the compile-time import voodoo dance.

To get around this nightmare, wrap your plugin definition in a C<BEGIN> block.


    BEGIN {  
        package Dancer2::Plugin::Foo;

        use Dancer2::Plugin2;

            has bar => (
                is => 'ro',
                from_config => 1,
            );

            plugin_keywords qw/ bar /;

    }

    {  
        package MyApp; 

        use Dancer2;
        use Dancer2::Plugin::Foo;

        bar();
    }

=head3 You cannot overwrite a locally defined method (bar) with a reader

If you set an object attribute of your plugin to be a keyword as well, you need
to call C<plugin_keywords> after the attribute definition.

    package Dancer2::Plugin::Foo;

    use Dancer2::Plugin2;

    has bar => (
        is => 'ro',
    );

    plugin_keywords 'bar';

=cut
