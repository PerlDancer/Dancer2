package Dancer2;
# ABSTRACT: Lightweight yet powerful web application framework

use strict;
use warnings;
use List::Util  'first';
use Class::Load 'load_class';
use Dancer2::Core;
use Dancer2::Core::App;
use Dancer2::Core::Runner;
use Dancer2::FileUtils;

our $AUTHORITY = 'SUKRIA';

# set version in dist.ini now
# but we still need a basic version for
# the tests
$Dancer2::VERSION ||= '0.143000'; # 2.14.3

our $runner;

sub runner   {$runner}
sub psgi_app { __PACKAGE__->runner->psgi_app }

sub import {
    my ( $class,  @args   ) = @_;
    my ( $caller, $script ) = caller;

    strict->import;
    warnings->import;
    utf8->import;

    my @final_args;
    foreach my $arg (@args) {
        grep +( $arg eq $_ ), qw<:script :syntax>
            and next;

        if ( substr( $arg, 0, 1 ) eq '!' ) {
            push @final_args, $arg, 1;
        } else {
            push @final_args, $arg;
        }
    }

    scalar @final_args % 2
      and die q{parameters must be key/value pairs, ':script' or '!keyword'};

    my %final_args = @final_args;

    my $appname = delete $final_args{appname};
    $appname ||= $caller;

    # never instantiated the runner, should do it now
    if ( not defined $runner ) {
        $runner = Dancer2::Core::Runner->new();
    }

    # Search through registered apps, creating a new app object
    # if we do not find one with the same name.
    my $app;
    ($app) = first { $_->name eq $appname } @{ $runner->apps };

    if ( ! $app ) {
        # populating with the server's postponed hooks in advance
        $app = Dancer2::Core::App->new(
            name            => $appname,
            caller          => $script,
            environment     => $runner->environment,
            postponed_hooks => $runner->postponed_hooks,
        );

        # register the app within the runner instance
        $runner->register_application($app);
    }

    _set_import_method_to_caller($caller);

    # use config dsl class, must extend Dancer2::Core::DSL
    my $config_dsl = $app->setting('dsl_class') || 'Dancer2::Core::DSL';
    $final_args{dsl} ||= $config_dsl;

    # load the DSL, defaulting to Dancer2::Core::DSL
    load_class( $final_args{dsl} );
    my $dsl = $final_args{dsl}->new( app => $app );
    $dsl->export_symbols_to( $caller, \%final_args );
}

sub _set_import_method_to_caller {
    my ($caller) = @_;

    my $import = sub {
        my ( $self, %options ) = @_;

        my $with = $options{with};
        for my $key ( keys %$with ) {
            $self->dancer_app->setting( $key => $with->{$key} );
        }
    };

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::import"} = $import;
    }
}

1;

__END__

=encoding UTF-8

=head1 DESCRIPTION

Dancer2 is the new generation of L<Dancer>, the lightweight web-framework for
Perl. Dancer2 is a complete rewrite based on L<Moo>.

Dancer2 can optionally use XS modules for speed, but at its core remains
fatpackable (packable by L<App::FatPacker>) so you could easily deploy Dancer2
applications on hosts that do not support custom CPAN modules.

Dancer2 is easy and fun:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance;

This is the main module for the Dancer2 distribution. It contains logic for
creating a new Dancer2 application.

You are welcome to join our mailing list.
For subscription information, mail address and archives see
L<http://lists.preshweb.co.uk/mailman/listinfo/dancer-users>.

We are also on IRC: #dancer on irc.perl.org.

=head2 Documentation Index

Documentation on Dancer2 is split into several manpages. Below is a
complete outline on where to go for help.

=over 4

=item * Dancer2 Tutorial

If you are new to the Dancer approach, you should start by reading
our L<Dancer2::Tutorial>.

=item * Dancer2 Manual

L<Dancer2::Manual> is the reference for Dancer2. Here you will find
information on the concepts of Dancer2 application development and
a comprehensive reference to the Dancer2 domain specific
language.

=item * Dancer2 Cookbook

There are some situations that are common to a lot of users. For
example, application deployment. in L<Dancer2::Cookbook> you will find
recipes for common tasks, like defining routes, storing data as
sessions or cookies, using templates, configuring and logging, writing
REST services, and deploying your Dancer2 application using different
technologies.

=item * Dancer2 Config

For configuration file details refer to L<Dancer2::Config>. It is a
complete list of all configuration options.

=item * Dancer2 Plugins

Refer to L<Dancer2::Plugins> for a partial list of available Dancer2
plugins. Note that although we try to keep this list up to date we
expect plugin authors to tell us about new modules.

=back

=func my $runner=runner();

Returns the current runner. It is of type L<Dancer2::Core::Runner>.

=cut

=method import;

If it doesn't exist already, C<import> creates a new runner, imports strict
and warnings, loads additional libraries, creates a new Dancer2 app (of type
L<Dancer2::Core::App>) and exports the DSL symbols to the caller.

If any additional argument processing is needed, it will be done at this point.

Import gets called when you use Dancer2. You can specify import options giving
you control over the keywords that will be imported into your webapp and other
things:

    use Dancer2 '!quux'; # Don't import DSL keyword quux
    use Dancer2 appname => 'MyAwesomeApp'; # Add routes and hooks to MyAwesomeApp
    use Dancer2 ( foo => 'bar' ); # sets option foo to bar (currently not implemented)

=head1 AUTHORS

=head2 CORE DEVELOPERS

    Alberto Simões
    Alexis Sukrieh
    Damien Krotkine
    David Golden
    David Precious
    Franck Cuny
    Mickey Nasriachi
    Russell Jenkins
    Sawyer X
    Stefan Hornburg (Racke)
    Steven Humphrey
    Yanick Champoux

=head2 CONTRIBUTORS

    Ahmad M. Zawawi
    Alex Beamish
    Alexander Karelas
    Alexandr Ciornii
    Andrew Grangaard
    Andrew Inishev
    andrewsolomon
    Ashvini V
    B10m
    baynes
    Blabos de Blebe
    Breno G. de Oliveira
    Celogeek
    Cesare Gargano
    Christian Walde
    Colin Kuskie
    cym0n
    Dale Gallagher
    David Steinbrunner
    Dinis Rebolo
    Erik Smit
    geistteufel
    Gideon D'souza
    Graham Knop
    Gregor Herrmann
    Grzegorz Rożniecki
    Hobbestigrou
    Ivan Bessarabov
    Jakob Voss
    James Aitken
    Jason A. Crome
    Javier Rojas
    Jean Stebens
    Jonathan Scott Duff
    Julio Fraire
    Keith Broughton
    Mark A. Stratman
    Mateu X Hunter
    Matt Phillips
    Matt S Trout
    Maurice
    Michał Wojciechowski
    mokko
    Olivier Mengué
    Omar M. Othman
    Pau Amma
    Pedro Melo
    Rick Yakubowski
    Sam Kington
    Samit Badle
    Shlomi Fish
    Slava Goltser
    smashz
    Tom Hukins
    Upasana
    Vincent Bachelier
