package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use 5.12.0;
use strict;
use warnings;
use List::Util 'first';
use Module::Runtime 'use_module';
use Import::Into;
use Dancer2::Core;
use Dancer2::Core::App;
use Dancer2::Core::Runner;

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

Dancer2 is the new generation of L<Dancer>, the lightweight web framework for
Perl. Dancer2 is a complete rewrite based on L<Moo>.

Dancer2 can optionally use XS modules for speed, but at its core remains
fatpackable (via L<App::FatPacker>), enabling you to easily deploy Dancer2
applications on hosts that do not support custom CPAN modules.

Creating web applications with Dancer2 is easy and fun:

    #!/usr/bin/env perl

    package HelloWorld;
    use Dancer2;

    get '/' => sub {
        return "Hello, world!";
    };

    true;

    HelloWorld->to_app;

This is the main module for the Dancer2 distribution. It contains logic for
creating a new Dancer2 application.

=head2 Documentation Index

You have questions. We have answers.

=over 4

=item * Dancer2 Tutorial

Want to learn by example? The L<Dancer2::Manual::Tutorial> will take you from
installation to a working application.

item * Quick Start

Want to get going faster? L<Quick Start|Dancer2::Manual::QuickStart> will help you install Dancer2
and bootstrap a new application quickly.

=item * Dancer2 Manual

Want to gain understanding of Dancer2 so you can use it best? The
L<Dancer2::Manual> is a comprehensive guide to the framework.

=item * Dancer2 Keywords

Looking for list of all the keywords? The L<DSL guide|Dancer2::Manual::Keywords>
documents the entire Dancer2 DSL.

=item * Dancer2 Config

Need to fine tune your application? The L<configuration guide|Dancer2::Manual::Config>
is the complete reference to all configuration options.

=item * Dancer2 Deployment

Ready to get your application off the ground? L<Deploying Dancer2 applications|Dancer2::Manual::Deployment>
helps you deploy your application to a real-world host.

=item * Dancer2 Cookbook

How do I...? Our L<cookbook|Dancer2::Manual::Cookbook> comes with various recipes
in many tasty flavors!

=item * Dancer2 Plugins

Looking for add-on functionality for your application? The L<plugin guide|Dancer2::Manual::Plugins>
contains our curated list of recommended plugins.

For information on how to author a plugin, see L<the plugin author's guide|Dancer2::Plugin/Writing the plugin>.

=item * Dancer2 Migration guide

Starting from Dancer 1? Jump over to the L<migration guide|Dancer2::Manual::Migration>
to learn how to make the smoothest transition to Dancer2.

=back

=head3 Other Documentation

=over

=item * Core and Community Policy, and Standards of Conduct

The L<Dancer core and community policy, and standards of conduct|Dancer2::Policy> defines
what constitutes acceptable behavior in our community, what behavior is considered
abusive and unacceptable, and what steps will be taken to remediate inappropriate
and abusive behavior. By participating in any public forum for Dancer or its
community, you are agreeing to the terms of this policy.

=item * GitHub Wiki

Our L<GitHub wiki|https://github.com/PerlDancer/Dancer2/wiki> has community-contributed
documentation, as well as other information that doesn't quite fit within
this manual.

=item * Contributing

The L<contribution guidelines|https://github.com/PerlDancer/Dancer2/blob/master/Contributing.md> describe
how to set up your development environment to contribute to the development of Dancer2,
Dancer2's Git workflow, submission guidelines, and various coding standards.

=item * Deprecation Policy

The L<deprecation policy|Dancer2::DeprecationPolicy> defines the process for removing old,
broken, unused, or outdated code from the Dancer2 codebase. This policy is critical
for guiding and shaping future development of Dancer2.

=back

=head1 SECURITY REPORTS

If you need to report a security vulnerability in Dancer2, send all pertinent
information to L<dancer-security@dancer.pm|mailto:dancer-security@dancer.pm>, or report it
via the GitHub security tool. These reports will be addressed in the earliest possible
timeframe.

=head1 SUPPORT

You are welcome to join our mailing list.
For subscription information, mail address and archives see
L<http://lists.preshweb.co.uk/mailman/listinfo/dancer-users>.

We are also on IRC: #dancer on irc.perl.org.

=head1 AUTHORS

=head2 CORE DEVELOPERS

    Alberto Simões
    Alexis Sukrieh
    D Ruth Holloway (GeekRuthie)
    Damien Krotkine
    David Precious
    Franck Cuny
    Jason A. Crome
    Mickey Nasriachi
    Peter Mottram (SysPete)
    Russell Jenkins
    Sawyer X
    Stefan Hornburg (Racke)
    Yanick Champoux

=head2 CORE DEVELOPERS EMERITUS

    David Golden
    Steven Humphrey

=head2 CONTRIBUTORS

    A. Sinan Unur
    Abdullah Diab
    Achyut Kumar Panda
    Ahmad M. Zawawi
    Alex Beamish
    Alexander Karelas
    Alexander Pankoff
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
    cloveistaken
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
    Elliot Holden
    Emil Perhinschi
    Erik Smit
    Fayland Lam
    ferki
    Gabor Szabo
    GeekRuthie
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
    icyavocado
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
    Karen Etheridge
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
    mauke
    Maurice
    MaxPerl
    Ma_Sys.ma
    Menno Blom
    Michael Kröll
    Michał Wojciechowski
    Mike Katasonov
    Mikko Koivunalho
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
    Paul Clements
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
    Steve Bertrand
    Steve Dondley
    Steven Humphrey
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
