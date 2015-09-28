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
            code   => sub { 'farewell!' },
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

    use Dancer2::Plugin::Polite ':app';

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

=head3 Accessing the parent Dancer app

If the plugin is instantiated within a Dancer app, it'll be
accessible via the method C<app()>.

    sub BUILD {
        my $plugin = shift;

        $plugin->app->add_route( ... );
    }


=head2 Using the plugin within the app

A plugin is loaded via

    use Dancer2::Plugin::Polite ':app';

The C<:app> must be there for the plugin to be tied to the app, and for the 
keywords to be imported to the namespace.

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


=cut

use strict;
use warnings;

use Moo;

extends 'Exporter::Tiny';

our @EXPORT = qw/ :plugin  /;
our @EXPORT_OK = qw/ :app  /;

sub _exporter_expand_tag {
    my( $class, $name, $args, $global ) = @_;

    my $caller = $global->{into};

    if ( $name eq 'plugin' ) {
        eval "{ package $caller; use Moo; extends 'Dancer2::Plugin2'; our %PluginKeywords; }";
        return ( [ 'plugin_keywords' => { class => $caller } ] ) x ( $caller =~ /^Dancer2::Plugin/ );
    }

    return unless $name eq 'app';

    die "plugin called with ':app' in a class without app()\n"
        unless $caller->can('app');

    ( my $short = $class ) =~ s/Dancer2::Plugin:://;

    my $app = eval "${caller}::app()";

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
                    : eval '\&'.$class."::$name";
                eval "{ \$${class}::PluginKeywords{'$name'} = \$sub }"; 
            }
        }
    }

    my $p = $args->{plugin};
    my $sub = $p->keywords->{$name};
    return $name => sub(@) { $sub->($p,@_) };
}


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
        $config->{plugins}{$package}
    },
);

has keywords => (
    is => 'ro',
    default => sub {
        my $self = shift;
        my $class = ref $self;

        +{
            map { eval "\%${class}::PluginKeywords" } 
                eval "\@${class}::ISA", $class
        }
    },
);

1;
