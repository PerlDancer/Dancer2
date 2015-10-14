package Dancer2::Plugin2;
# ABSTRACT: base class for Dancer2 plugins

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

Keywords that the plugin wishes to export to the Dancer2 app must be defined via the C<plugin_keywords> keyword:

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

use strict;
use warnings;

use Moo;
use MooX::ClassAttribute;
use List::Util qw/ reduce /;

extends 'Exporter::Tiny';

with 'Dancer2::Core::Role::Hookable';

our @EXPORT = qw/ :plugin /;

sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    my $caller = $global->{into};

    if ( $name eq 'plugin' ) {
        eval <<"END";
            { 
                package $caller; 
                use Moo; 
                extends 'Dancer2::Plugin2'; 
                our \@EXPORT = ( ':app' ); 
                our \$_moo_has = $caller->can('has');
                no strict 'refs';
                no warnings 'redefine';
                \*{'$caller'.'::has'} = sub {
                    \$_moo_has->( Dancer2::Plugin2::_p2_has(\@_) );
                }
            }
END
        die $@ if $@;

        return () unless $caller =~ /^Dancer2::Plugin/;

        return (
            [ 'plugin_keywords' => { class => $caller } ],
            [ 'plugin_hooks'    => { class =>  $caller } ],
            #        [ '_p2_has'  => { class => $caller }],
        )
    }

    return unless $name eq 'app' 
              and $caller->can('app');

    my $app = eval "${caller}::app()" or return;

    return unless $app->can('with_plugins');

    ( my $short = $class ) =~ s/Dancer2::Plugin:://;

    my $plugin = $app->with_plugins( $short );
    $global->{plugin} = $plugin;

    return unless $class->can('keywords');

    map { [ $_ =>  {plugin => $plugin}  ] } keys %{ $plugin->keywords };
}

sub _exporter_expand_sub {
    my( $plugin, $name, $args, $global ) = @_;

    if ( $name eq 'plugin_keywords' ) {
        my $class = $args->{class};
        return $name => sub(@) {
            while( my $name = shift @_ ) {
                my $sub = ref $_[0] eq 'CODE' 
                    ? shift @_ 
                    : eval '\&'.$class."::" . ( ref $name ? $name->[0] : $name );
                $plugin->ClassKeywords->{$_} = $sub for ref $name ? @$name : $name;
            }
        }
    }

    if ( $name eq 'plugin_hooks' ) {
        my $class = $args->{class};
        return $name => sub(@) {
            $class->add_hooks(@_);
        }
    }

#    if( $name eq '_p2_has' ) {
    #       return '_p2_has'
    #}

    my $p = $args->{plugin};
    my $sub = $p->keywords->{$name};
    return $name => sub(@) { $sub->($p,@_) };
}

sub _p2_has {
    my( $name, %args ) = @_;

    if( my $config_name = delete $args{'from_config'} ) {
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
        }
    }

    return $name => %args;
};


has app => (
#    isa => Object['Dancer2::Core::App'],
    is => 'ro',
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

class_has ClassKeywords => (
    is => 'ro',
    default => sub {
        +{}
    }
);

has keywords => (
    is => 'ro',
    default => sub {
        my $self = shift;
        +{ %{$self->ClassKeywords} }
    },
);

class_has ClassHooks => (
    is => 'ro',
    default => sub {
        [];
    }
);

has '+hooks' => (
    default => sub {
        my $plugin = shift;
        my $name = 'plugin.' . lc ref $plugin;
        $name =~ s/Dancer2::Plugin:://i;
        $name =~ s/::/_/;

        +{ 
            map { join( '.', $name, $_ ) => [] }
                @{ $plugin->ClassHooks }  
        };
    },
);

sub add_hooks {
    push @{ $_[0]->ClassHooks }, @_;
}

sub supported_hooks { [] }

sub hook_aliases { +{} }

1;
