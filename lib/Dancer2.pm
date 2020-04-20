package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use strict;
use warnings;
use List::Util 'first';
use Module::Runtime 'use_module';
use Import::Into;
use Dancer2::Core;
use Dancer2::Core::App;
use Dancer2::Core::Runner;
use Dancer2::FileUtils;

our $AUTHORITY = 'SUKRIA';

sub VERSION { shift->SUPER::VERSION(@_) || '0.000000_000' }

our $runner;

sub runner   {$runner}
sub psgi_app { shift->runner->psgi_app(@_) }

sub import {
    my ($class,  @args)   = @_;
    my ($caller, $script) = caller;

    my @final_args;
    my $clean_import;
    foreach my $arg (@args) {

        # ignore, no longer necessary
        # in the future these will warn as deprecated
        grep +($arg eq $_), qw<:script :syntax :tests>
          and next;

        if ($arg eq ':nopragmas') {
            $clean_import++;
            next;
        }

        if (substr($arg, 0, 1) eq '!') {
            push @final_args, $arg, 1;
        }
        else {
            push @final_args, $arg;
        }
    }

    $clean_import
      or $_->import::into($caller)
      for qw<strict warnings utf8>;

    scalar @final_args % 2
      and die q{parameters must be key/value pairs or '!keyword'};

    my %final_args = @final_args;

    my $appname = delete $final_args{appname};
    $appname ||= $caller;

    # never instantiated the runner, should do it now
    if (not defined $runner) {
        $runner = Dancer2::Core::Runner->new();
    }

    # Search through registered apps, creating a new app object
    # if we do not find one with the same name.
    my $app;
    ($app) = first { $_->name eq $appname } @{$runner->apps};

    if (!$app) {

        # populating with the server's postponed hooks in advance
        $app = Dancer2::Core::App->new(
            name            => $appname,
            caller          => $script,
            environment     => $runner->environment,
            postponed_hooks => $runner->postponed_hooks->{$appname} || {},
        );

        # register the app within the runner instance
        $runner->register_application($app);
    }

    _set_import_method_to_caller($caller);

    # use config dsl class, must extend Dancer2::Core::DSL
    my $config_dsl = $app->setting('dsl_class') || 'Dancer2::Core::DSL';
    $final_args{dsl} ||= $config_dsl;

    # load the DSL, defaulting to Dancer2::Core::DSL
    my $dsl = use_module($final_args{dsl})->new(app => $app);
    $dsl->export_symbols_to($caller, \%final_args);
}

sub _set_import_method_to_caller {
    my ($caller) = @_;

    my $import = sub {
        my ($self, %options) = @_;

        my $with = $options{with};
        for my $key (keys %$with) {
            $self->dancer_app->setting($key => $with->{$key});
        }
    };

    {
        ## no critic
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

=head2 Documentation Index

Documentation on Dancer2 is split into several sections. Below is a
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

=item * Dancer2 Keywords

The keywords for Dancer2 can be found under L<DSL Keywords|Dancer2::Manual/DSL KEYWORDS>.

=item * Dancer2 Deployment

For configuration examples of different deployment solutions involving
Dancer2 and Plack, refer to L<Dancer2::Manual::Deployment>.

=item * Dancer2 Cookbook

Specific examples of code for real-life problems and some 'tricks' for
applications in Dancer can be found in L<Dancer2::Cookbook>

=item * Dancer2 Config

For configuration file details refer to L<Dancer2::Config>. It is a
complete list of all configuration options.

=item * Dancer2 Plugins

Refer to L<Dancer2::Plugins> for a partial list of available Dancer2
plugins. Note that although we try to keep this list up to date we
expect plugin authors to tell us about new modules.

For information on how to author a plugin, see L<Dancer2::Plugin/Writing the plugin>.

=item * Dancer2 Migration guide

L<Dancer2::Manual::Migration> provides the most up-to-date instruction on
how to convert a Dancer (1) based application to Dancer2.

=back

=func my $runner=runner();

Returns the current runner. It is of type L<Dancer2::Core::Runner>.

=cut

=head1 SECURITY REPORTS

If you need to report a security vulnerability in Dancer2, send all pertinent
information to L<mailto:dancer-security@dancer.pm>. These matters are taken
extremely seriously, and will be addressed in the earliest timeframe possible.

=head1 SUPPORT

You are welcome to join our mailing list.
For subscription information, mail address and archives see
L<http://lists.preshweb.co.uk/mailman/listinfo/dancer-users>.

We are also on IRC: #dancer on irc.perl.org.

=head1 AUTHORS

=head2 CORE DEVELOPERS

    Alberto Simões
    Alexis Sukrieh
    Damien Krotkine
    David Precious
    Franck Cuny
    Jason A. Crome
    Mickey Nasriachi
    Peter Mottram (SysPete)
    Russell Jenkins
    Sawyer X
    Stefan Hornburg (Racke)
    Steven Humphrey
    Yanick Champoux

=head2 CORE DEVELOPERS EMERITUS

    David Golden

=head2 CONTRIBUTORS

    A. Sinan Unur
    Abdullah Diab
    Ahmad M. Zawawi
    Alex Beamish
    Alexander Karelas
    Alexandr Ciornii
    Andrew Beverley
    Andrew Grangaard
    Andrew Inishev
    Andrew Solomon
    Andy Jack
    Ashvini V
    B10m
    Bas Bloemsaat
    baynes
    Ben Hutton
    Ben Kaufman
    biafra
    Blabos de Blebe
    Breno G. de Oliveira
    cdmalon
    Celogeek
    Cesare Gargano
    Charlie Gonzalez
    chenchen000
    Chi Trinh
    Christian Walde
    Christopher White
    Colin Kuskie
    cym0n
    Dale Gallagher
    Dan Book (Grinnz)
    Daniel Böhmer
    Daniel Muey
    Daniel Perrett
    Dave Jacoby
    Dave Webb
    David (sbts)
    David Steinbrunner
    David Zurborg
    Davs
    Deirdre Moran
    Dennis Lichtenthäler
    Dinis Rebolo
    dtcyganov
    Erik Smit
    Fayland Lam
    ferki
    Gabor Szabo
    geistteufel
    Gideon D'souza
    Gil Magno
    Glenn Fowler
    Graham Knop
    Gregor Herrmann
    Grzegorz Rożniecki
    Hobbestigrou
    Hunter McMillen
    ice-lenor
    Ivan Bessarabov
    Ivan Kruglov
    JaHIY
    Jakob Voss
    James Aitken
    James Raspass
    James McCoy
    Jason Lewis
    Javier Rojas
    Jean Stebens
    Jens Rehsack
    Joel Berger
    Johannes Piehler
    Jonathan Cast
    Jonathan Scott Duff
    Joseph Frazer
    Julien Fiegehenn (simbabque)
    Julio Fraire
    Kaitlyn Parkhurst (SYMKAT)
    kbeyazli
    Keith Broughton
    lbeesley
    Lennart Hengstmengel
    Ludovic Tolhurst-Cleaver
    Mario Zieschang
    Mark A. Stratman
    Marketa Wachtlova
    Masaaki Saito
    Mateu X Hunter
    Matt Phillips
    Matt S Trout
    Maurice
    MaxPerl
    Ma_Sys.ma
    Menno Blom
    Michael Kröll
    Michał Wojciechowski
    Mike Katasonov
    Mohammad S Anwar
    mokko
    Nick Patch
    Nick Tonkin
    Nigel Gregoire
    Nikita K
    Nuno Carvalho
    Olaf Alders
    Olivier Mengué
    Omar M. Othman
    pants
    Patrick Zimmermann
    Pau Amma
    Paul Cochrane
    Paul Williams
    Pedro Bruno
    Pedro Melo
    Philippe Bricout
    Ricardo Signes
    Rick Yakubowski
    Ruben Amortegui
    Sakshee Vijay (sakshee3)
    Sam Kington
    Samit Badle
    Sebastien Deseille (sdeseille)
    Sergiy Borodych
    Shlomi Fish
    Slava Goltser
    Snigdha
    Steve Dondley
    Tatsuhiko Miyagawa
    Timothy Alexis Vass
    Tina Müller
    Tom Hukins
    Upasana Shukla
    Utkarsh Gupta
    Vernon Lyon
    Victor Adam
    Vince Willems
    Vincent Bachelier
    xenu
    Yves Orton
