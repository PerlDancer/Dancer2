package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use strict;
use warnings;
use Class::Load 'load_class';
use Dancer2::Core;
use Dancer2::Core::Runner;
use Dancer2::Core::App;
use Dancer2::FileUtils;

our $AUTHORITY = 'SUKRIA';

# set version in dist.ini now
# but we still need a basic version for
# the tests
$Dancer2::VERSION ||= '0.09';    # 2.0.9

=head1 DESCRIPTION

Dancer2 is the new generation of L<Dancer>, the lightweight web-framework for 
Perl. Dancer2 is a complete rewrite based on L<Moo>. 

Dancer2 is easy and fun:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance;

This is the main module for the Dancer2 distribution. It contains logic for 
creating a new Dancer2 application. 

You are also welcome to join our mailing list at dancer-users@perldancer.org, 
and we're also on IRC: #dancer on irc.perl.org.

=head2 Documentation Index

Documentation on Dancer2 is split up in different manpages. This is a
comprehensive outline on where you will find your help.

=over 4

=item * Dancer2 Tutorial

If you are new to Dancer philosophy we suggest you to start following
our L<Dancer2::Tutorial>.

=item * Dancer2 Manual

L<Dancer2::Manual> is the reference for Dancer2. Here you will find
information about the concepts on Dancer2 application development as
well as a comprehensive reference to the Dancer2 domain specific
language.

=item * Dancer2 Cookbook

There are some situations that are common to a lot of users. For
example, application deployment. On L<Dancer2::Cookbook> you will find
reciped for common tasks, from defining routes, storing data as
sessions or cookies, using templates, configuring and logging, writing
REST services and deploying your dancer application using different
technologies.

=item * Dancer2 Config

For configuration file details refer to L<Dancer2::Config>. It is a
comprehensive list of all possible configuration options.

=item * Dancer2 Plugins

Refer L<Dancer2::Plugins> includes a list of (some) available Dancer2
plugins. Note that although we try to keep this list up to date we
rely on plugin authors to warn us about new modules.

=back

=func my $runner=runner();

Returns the current runner. It is of type L<Dancer2::Core::Runner>.

=cut

our $runner;

sub runner {$runner}

=method import;

If it doesn't exist already, C<import> creates a new runner, imports strict 
and warnings, loads additional libraries, creates a new Dancer2 app (of type 
L<Dancer2::Core::App>) and exports the DSL symbols to the caller.

If any additional argument processing is needed, it will be done at this point.

Import gets called when you use Dancer2. You can specify import options giving 
you control over the keywords that will be imported into your webapp and other 
things:

    use Dancer2 ':script';

=head3 Import Options

=over 4

=item C<:script>

Do not process arguments.

=back

=cut

sub import {
    my ( $class,  @args )   = @_;
    my ( $caller, $script ) = caller;

    strict->import;
    utf8->import;

    my @final_args;
    my $as_script = 0;
    foreach (@args) {
        if ( $_ eq ':script' ) {
            $as_script = 1;
        }
        elsif ( substr( $_, 0, 1 ) eq '!' ) {
            push @final_args, $_, 1;
        }
        else {
            push @final_args, $_;
        }
    }

    scalar(@final_args) % 2
      and die
      "parameters to 'use Dancer2' should be one of : 'key => value', ':script', or !<keyword>, where <keyword> is a DSL keyword you don't want to import";
    my %final_args = @final_args;

    $final_args{dsl} ||= 'Dancer2::Core::DSL';

    # never instantiated the runner, should do it now
    if ( not defined $runner ) {

        # TODO should support commandline options as well

        $runner = Dancer2::Core::Runner->new( caller => $script, );
    }

    my $server = $runner->server;

    # the app object
    # populating with the server's postponed hooks in advance
    my $app = Dancer2::Core::App->new(
        name            => $caller,
        environment     => $runner->environment,
        location        => $runner->location,
        runner_config   => $runner->config,
        postponed_hooks => $server->postponed_hooks,
    );

    _set_import_method_to_caller($caller);

    # register the app within the runner instance
    $server->register_application($app);

    # load the DSL, defaulting to Dancer2::Core::DSL
    load_class( $final_args{dsl} );
    my $dsl = $final_args{dsl}->new( app => $app );
    $dsl->export_symbols_to( $caller, \%final_args );

    #
    #    $as_script = 1 if $ENV{PLACK_ENV};
    #
    #    Dancer2::GetOpt->process_args() if !$as_script;
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
