package Dancer2::Plugin;
# ABSTRACT: base class for Dancer2 plugins

use strict;
use warnings;

use Moo;
use Carp;
use List::Util qw/ reduce /;
use Module::Runtime 'require_module';
use Attribute::Handlers;
use Scalar::Util;
use Ref::Util qw<is_arrayref is_coderef>;

our $CUR_PLUGIN;

extends 'Exporter::Tiny';

with 'Dancer2::Core::Role::Hookable';

has app => (
    is       => 'ro',
    weak_ref => 1,
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

my $REF_ADDR_REGEX = qr{
    [A-Za-z0-9\:\_]+
    =HASH
    \(
        ([0-9a-fx]+)
    \)
}x;
my %instances;

# backwards compatibility
our $_keywords_by_plugin = {};

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

    $self->isa('Dancer2::Plugin')
        or croak "Cannot call plugin hook ($name) from outside plugin";
    $plugin_class =~ s/^Dancer2::Plugin:://; # short names

    my $full_name = 'plugin.' . lc($plugin_class) . ".$name";
    $full_name =~ s/::/_/g;

    $self->app->execute_hook( $full_name, @args );
}

sub find_plugin {
    my ( $self, $name ) = @_;
    return $self->app->find_plugin($name);
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

    if ( is_coderef($config_name) ) {
        $args{default} ||= $config_name;
        $config_name = 1;
    }

    $config_name = $name if $config_name eq '1';
    my $orig_default = $args{default} || sub{};
    $args{default} = sub {
        my $plugin = shift;
        my $value = reduce { eval { $a->{$b} } } $plugin->config, split /\./, $config_name;
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

sub PluginKeyword :ATTR(CODE,BEGIN) {
    my( $class, $sym_ref, $code, undef, $args ) = @_;

    # importing at BEGIN stage doesn't work with 5.10 :-(
    return unless ref $sym_ref;

    my $func_name = *{$sym_ref}{NAME};

    $args = join '', @$args if is_arrayref($args);

    for my $name ( split ' ', $args || $func_name ) {
        $class->keywords->{$name} = $code;
    }

}

## EXPORT STUFF ##############################################################

# this @EXPORT will only be taken
# into account when we do a 'use Dancer2::Plugin'
# I.e., it'll only do its magic for the
# plugins themselves, not when they are
# called
our @EXPORT = qw/ :plugin /;

# compatibility - it will be removed soon!
my $no_dsl = {};
my $exported_app = {};
sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    my $caller = $global->{into};

    $name eq 'no_dsl' and $no_dsl->{$caller} = 1;
    # no_dsl check here is for compatibility only
    # it will be removed soon!
    return _exporter_plugin($caller)
        if $name eq 'plugin' or $name eq 'no_dsl';

    return _exporter_app($class,$caller,$global)
        if $name eq 'app' and $caller->can('app') and !$no_dsl->{$class};

    return;

}

# plugin has been called within a D2 app. Modify
# the app and export keywords
sub _exporter_app {
    my( $class, $caller, $global ) = @_;

    $exported_app->{$caller} = 1;

    # The check for ->dsl->app is to handle plugins as well.
    # Otherwise you can only import from a plugin to an app,
    # but with this, you can import to anything
    # that has a DSL with an app, which translates to "also plugins"
    my $app = eval("${caller}::app()") || eval { $caller->dsl->app } ## no critic qw(BuiltinFunctions::ProhibitStringyEval)
        or return; ## no critic

    return unless $app->can('with_plugin');

    my $plugin = $app->with_plugin( '+' . $class );
    $global->{'plugin'} = $plugin;

    return unless $class->can('keywords');

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

            # this adds it to the plugin
            $plugin->hook_aliases->{$hook} = $full_name;

            # this adds it to the app
            $plugin->app->hook_aliases->{$hook} = $full_name;

            # copy the hooks from the plugin to the app
            # this is in case they were created at import time
            # rather than after
            @{ $plugin->app->hooks }{ keys %{ $plugin->hooks } } =
                values %{ $plugin->hooks };
        }
    }

    {
        # get the reference
        my ($plugin_addr) = "$plugin" =~ $REF_ADDR_REGEX;

        $instances{$plugin_addr}{'config'} = sub { $plugin->config };
        $instances{$plugin_addr}{'app'}    = $plugin->app;

        Scalar::Util::weaken( $instances{$plugin_addr}{'app'} );

        ## no critic
        no strict 'refs';

        # we used a forward declaration
        # so the compiled form "plugin_setting;" can be overridden
        # with this implementation,
        # which works on runtime ("plugin_setting()")
        # we can't use can() here because the forward declaration will
        # create a CODE stub
        no warnings 'redefine';
        *{"${class}::plugin_setting"} = sub {
            my ($plugin_addr) = "$CUR_PLUGIN" =~ $REF_ADDR_REGEX;

            $plugin_addr
                or Carp::croak('Can\'t find originating plugin');

            # we need to do this because plugins might call "set"
            # in order to change plugin configuration but it doesn't
            # change the plugin object, it changes the app object
            # so we merge them.
            my $name = ref $CUR_PLUGIN;
            $name =~ s/^Dancer2::Plugin:://g;

            my $plugin_inst       = $instances{$plugin_addr};
            my $plugin_config     = $plugin_inst->{'config'}->();
            my $app_plugin_config = $plugin_inst->{'app'}->config->{'plugins'}{$name};

            return { %{ $plugin_config || {} }, %{ $app_plugin_config || {} } };
        };

        # FIXME:
        # why doesn't this work? it's like it's already defined somewhere
        # but i'm not sure where. seems like AUTOLOAD runs it.
        #$class->can('execute_hook') or
            *{"${class}::execute_hook"}   = sub {
                # this can also be called by App.pm itself
                # if the plugin is a
                # "candidate" for a hook
                # See: App.pm "execute_hook" method, "around" modifier
                if ( $_[0]->isa('Dancer2::Plugin') ) {
                    # this means it's probably our hook, we need to verify it
                    my ( $plugin_self, $hook_name, @args ) = @_;

                    my $plugin_class = lc $class;
                    $plugin_class =~ s/^dancer2::plugin:://;
                    $plugin_class =~ s{::}{_}g;

                    # you're either calling it with the full qualifier or not
                    # if not, use the execute_plugin_hook instead
                    if ( $plugin->hooks->{"plugin.$plugin_class.$hook_name"} ) {
                        Carp::carp("Please use fully qualified hook name or "
                                 . "the method execute_plugin_hook");
                        $hook_name = "plugin.$plugin_class.$hook_name";
                    }

                    $hook_name =~ /^plugin\.$plugin_class/
                        or Carp::croak('Unknown plugin called through other plugin');

                    # now we can't really use the app to execute it because
                    # the "around" modifier is the one calling us to begin
                    # with, so we need to call it directly ourselves
                    # this is okay because the modifier is there only to
                    # call candidates, like us (this is in fact how and
                    # why we were called)
                    $_->( $plugin_self, @args )
                        for @{ $plugin->hooks->{$hook_name} };

                    return;
                }

                return $plugin->app->execute_hook(@_);
        };
    }

    local $CUR_PLUGIN = $plugin;
    $_->($plugin) for @{ $plugin->_DANCER2_IMPORT_TIME_SUBS() };

    map { [ $_ =>  {plugin => $plugin}  ] } keys %{ $plugin->keywords };
}

# turns the caller namespace into
# a D2P2 class, with exported keywords
sub _exporter_plugin {
    my $caller = shift;
    require_module('Dancer2::Core::DSL');
    my $keywords_list = join ' ', keys %{ Dancer2::Core::DSL->dsl_keywords };

    eval <<"END"; ## no critic
        {
            package $caller;
            use Moo;
            use Carp ();
            use Attribute::Handlers;

            extends 'Dancer2::Plugin';

            our \@EXPORT = ( ':app' );

            around has => sub {
                my( \$orig, \$name, \%args ) = \@_;

                if (ref \$name eq 'ARRAY'
                        && exists \$args{'plugin_keyword'}
                        && ref \$args{'plugin_keyword'} eq 'ARRAY') {

                    Carp::croak('Setting "plugin_keyword" to an array is disallowed'
                        . ' when defining multiple attributes simultaneously');
                }

                \$orig->( ${caller}->_p2_has( \$_, \%args) )
                    for ref \$name ? @\$name : \$name;
            };

            sub PluginKeyword :ATTR(CODE,BEGIN) {
                goto &Dancer2::Plugin::PluginKeyword;
            }

            sub execute_plugin_hook {
                goto &Dancer2::Plugin::execute_plugin_hook;
            }

            my \$_keywords = {};
            sub keywords { \$_keywords }

            my \$_ClassHooks = [];
            sub ClassHooks { \$_ClassHooks }

            # this is important as it'll do the keywords mapping between the
            # plugin and the app
            sub register_plugin { Dancer2::Plugin::register_plugin(\@_) }

            sub register {
                my ( \$keyword, \$sub ) = \@_;
                \$_keywords->{\$keyword} = \$sub;

                \$keyword =~ /^[a-zA-Z_]+[a-zA-Z0-9_]*\$/
                  or Carp::croak(
                    "You can't use '\$keyword', it is an invalid name"
                  . " (it should match ^[a-zA-Z_]+[a-zA-Z0-9_]*\\\$ )");


                grep +( \$keyword eq \$_ ), qw<$keywords_list>
                    and Carp::croak("You can't use '\$keyword', this is a reserved keyword");

                \$Dancer2::Plugin::_keywords_by_plugin->{\$keyword}
                    and Carp::croak("You can't use \$keyword, "
                      . "this is a keyword reserved by "
                      . \$Dancer2::Plugin::_keywords_by_plugin->{\$keyword});

                \$Dancer2::Plugin::_keywords_by_plugin->{\$keyword} = "$caller";

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

            sub plugin_setting {};

            sub plugin_args {
                Carp::carp "Plugin DSL method 'plugin_args' is deprecated. "
                         . "Use '\\\@_' instead'.\n";

                \@_;
            }
        }
END

    $no_dsl->{$caller} or eval <<"END"; ## no critic
        {
            package $caller;

            # FIXME: AUTOLOAD might pick up on this
            sub dancer_app {
                Carp::carp "Plugin DSL method 'dancer_app' is deprecated. "
                         . "Use '\\\$self->app' instead'.\n";

                \$_[0]->app;
            }

            # FIXME: AUTOLOAD might pick up on this
            sub request {
                Carp::carp "Plugin DSL method 'request' is deprecated. "
                         . "Use '\\\$self->app->request' instead'.\n";

                \$_[0]->app->request;
            }

            # FIXME: AUTOLOAD might pick up on this
            sub var {
                Carp::carp "Plugin DSL method 'var' is deprecated. "
                         . "Use '\\\$self->app->request->var' instead'.\n";

                shift->app->request->var(\@_);
            }

            # FIXME: AUTOLOAD might pick up on this
            sub hook {
                Carp::carp "Plugin DSL method 'hook' is deprecated. "
                         . "Use '\\\$self->app->add_hook' instead'.\n";

                shift->app->add_hook(
                    Dancer2::Core::Hook->new( name => shift, code => shift ) );
            }

        }
END

    die $@ if $@;

    my $app_dsl_cb = _find_consumer();

    if ( $app_dsl_cb ) {
        my $dsl = $app_dsl_cb->();

        {
            ## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
            no strict 'refs';
            no warnings 'redefine';
            *{"${caller}::dsl"} = sub {$dsl};
        }
    }

    return map { [ $_ => { class => $caller } ] }
               qw/ plugin_keywords plugin_hooks /;
}

sub _find_consumer {
    my $class;

    ## no critic qw(ControlStructures::ProhibitCStyleForLoops)
    for ( my $i = 1; my $caller = caller($i); $i++ ) {
        $class = $caller->can('dsl')
            and last;
    }

    # If you use a Dancer2 plugin outside a Dancer App, this fails.
    # It also breaks a bunch of the tests. -- SX
    #$class
    #    or croak('Could not find Dancer2 app');

    return $class;
};

# This has to be called for now at the end of every plugin package, in order to
# map the keywords of the associated app to the plugin, so that these keywords
# can be called from within the plugin code. This function is deprecated, as
# it's tied to the old plugin system. It's kept here for backcompat reason, but
# should go away with the old plugin system.
sub register_plugin {

    my $plugin_module = caller(1);

    # if you ask yourself why we do the injection in the plugin
    # module namespace every time the plugin is used, and not only
    # once, it's because it can be used by different app that could
    # have a different DSL with a different list of keywords.

    my $_DANCER2_IMPORT_TIME_SUBS = $plugin_module->_DANCER2_IMPORT_TIME_SUBS;
    unshift(@$_DANCER2_IMPORT_TIME_SUBS, sub {
                my $app_dsl_cb = _find_consumer();

                # Here we want to verify that "register_plugin" compat keyword
                # was in fact only called from an app.
                $app_dsl_cb
                      or Carp::croak(
                        'I could not find a Dancer App for this plugin');

                my $dsl = $app_dsl_cb->();

                foreach my $keyword ( keys %{ $dsl->dsl_keywords} ) {
                    # if not yet defined, inject the keyword in the plugin
                    # namespace, but make sure the code will always get the
                    # coderef from the right associated app, because one plugin
                    # can be used by multiple apps. Note that we remove the
                    # first parameter (plugin instance) from what we pass to
                    # the keyword implementation of the App
                    no strict 'refs';
                    $plugin_module->can($keyword)
                      or *{"${plugin_module}::$keyword"} = sub {
                          my $coderef = shift()->app->name->can($keyword);
                          $coderef->(@_);
                      };
                }
            });
}

sub _exporter_expand_sub {
    my( $plugin, $name, $args, $global ) = @_;
    my $class = $args->{class};

    return _exported_plugin_keywords($plugin,$class)
        if $name eq 'plugin_keywords';

    return _exported_plugin_hooks($class)
        if $name eq 'plugin_hooks';

    $exported_app->{ $global->{'into'} }
        or Carp::croak('Specific subroutines cannot be exported from plugin');

    # otherwise, we're exporting a keyword

    my $p = $args->{plugin};
    my $sub = $p->keywords->{$name};
    return $name => sub(@) {
        # localize the plugin so we can get it later
        local $CUR_PLUGIN = $p;
        $sub->($p,@_);
    }
}

# "There's a good reason for this, I swear!"
#    -- Sawyer X
# basically, if someone adds a hook to the app directly
# that needs to access a DSL that needs the current object
# (such as "plugin_setting"),
# that object needs to be available
# So:
# we override App's "add_hook" to provide a register a
# different hook callback, that closes over the plugin when
# it's available, relocalizes it when the callback runs and
# after localizing it, calls the original hook callback
{
    ## no critic;
    no strict 'refs';
    no warnings 'redefine';
    my $orig_cb = Dancer2::Core::App->can('add_hook');
    $orig_cb and *{'Dancer2::Core::App::add_hook'} = sub {
        my ( $app, $hook ) = @_;

        my $hook_code = Scalar::Util::blessed($hook) ? $hook->code : $hook->{code};
        my $plugin    = $CUR_PLUGIN;

        $hook->{'code'} = sub {
            local $CUR_PLUGIN = $plugin;
            $hook_code->(@_);
        };

        $orig_cb->(@_);
    };
}


# define the exported 'plugin_keywords'
sub _exported_plugin_keywords{
    my( $plugin, $class ) = @_;

    return plugin_keywords => sub(@) {
        while( my $name = shift @_ ) {
            ## no critic
            my $sub = is_coderef($_[0])
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

    use Dancer2::Plugin;

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

=head2 Writing the plugin

=head3 C<use Dancer2::Plugin>

The plugin must begin with

    use Dancer2::Plugin;

which will turn the package into a L<Moo> class that inherits from L<Dancer2::Plugin>. The base class provides the plugin with
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

For perl 5.12 and higher, keywords can also be defined by adding the C<:PluginKeyword> attribute
to the function you wish to export.

For Perl 5.10, the export triggered by the sub attribute comes too late in the 
game, and the keywords won't be exported in the application namespace. 

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

C<Dancer2::Plugin> allows for a C<from_config> key in the attribute definition.
Its value is the plugin configuration key that will be used to initialize the attribute.

If it's given the value C<1>, the name of the attribute will be taken as the configuration key.

Nested hash keys can also be referred to using a dot notation.

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

=head3 Config becomes immutable

The plugin's C<config> attribute is loaded lazily on the first call to
C<config>. After this first call C<config> becomes immutable so you cannot
do the following in a test:

    use Dancer2;
    use Dancer2::Plugin::FooBar;

    set plugins => {
        FooBar => {
            wibble => 1,  # this is OK
        },
    };

    flibble(45);          # plugin keyword called which causes config read
    
    set plugins => {
        FooBar => {
            wibble => 0,  # this will NOT change plugin config
        },
    };

=head3 Accessing the parent Dancer app

If the plugin is instantiated within a Dancer app, it'll be
accessible via the method C<app()>.

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_route( ... );
    }

To use Dancer's DSL in your plugin:

    $self->dsl->debug( “Hi! I’m logging from your plugin!” );

See L<Dancer2::Manual/"DSL KEYWORDS"> for a full list of Dancer2 DSL.

=head2 Using the plugin within the app

A plugin is loaded via

    use Dancer2::Plugin::Polite;

The plugin will assume that it's loading within a Dancer module and will
automatically register itself against its C<app()> and export its keywords
to the local namespace. If you don't want this to happen, specify that you
don't want anything imported via empty parentheses when C<use>ing the module:

    use Dancer2::Plugin::Polite ();

=head2 Plugins using plugins

It's easy to use plugins from within a plugin:

    package Dancer2::Plugin::SourPuss;
    
    use Dancer2::Plugin; 
    use Dancer2::Plugin::Polite; 
    
    sub my_keyword { my $smiley = smiley(); } 

    1;

This does not export C<smiley()> into your application - it is only available
from within your plugin. However, from the example above, you can wrap 
DSL from other plugins and make it available from your plugin.

=head2 Utilizing other plugins

You can use the C<find_plugin> to locate other plugins loaded by the user,
in order to use them, or their information, directly:

    # MyApp.pm
    use Dancer2;
    use Dancer2::Plugin::Foo;
    use Dancer2::Plugin::Bar;

    # Dancer2::Plugin::Bar;
    ...

    sub my_keyword {
        my $self = shift;
        my $foo  = $self->find_plugin('Dancer2::Plugin::Foo')
            or $self->dsl->send_error('Could not find Foo');

        return $foo->foo_keyword(...);
    }

=head2 Hooks

New plugin hooks are declared via C<plugin_hooks>.

    plugin_hooks 'my_hook', 'my_other_hook';

Hooks are prefixed with C<plugin.plugin_name>. So the plugin
C<my_hook> coming from the plugin C<Dancer2::Plugin::MyPlugin> will have the hook name
C<plugin.myplugin.my_hook>.

Hooks are executed within the plugin by calling them via the associated I<app>.

    $plugin->execute_plugin_hook( 'my_hook' );

You can also call any other hook if you provide the full name using the
C<execute_hook> method:

    $plugin->app->execute_hook( 'core.app.route_exception' );

Or using their alias:

    $plugin->app->execute_hook( 'on_route_exception' );

B<Note:> If your plugin consumes a plugin that declares any hooks, those hooks 
are added to your application, even though DSL is not.

=head2 Writing Test Gotchas

=head3 Constructor for Dancer2::Plugin::Foo has been inlined and cannot be updated

You'll usually get this one because you are defining both the plugin and app
in your test file, and the runtime creation of Moo's attributes happens after
the compile-time import voodoo dance.

To get around this nightmare, wrap your plugin definition in a C<BEGIN> block.


    BEGIN {
        package Dancer2::Plugin::Foo;

        use Dancer2::Plugin;

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

    use Dancer2::Plugin;

    has bar => (
        is => 'ro',
    );

    plugin_keywords 'bar';

=cut
