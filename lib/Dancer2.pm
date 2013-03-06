package Dancer2;

# ABSTRACT: Lightweight yet powerful web application framework

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Dancer2::Core::Runner;
use Dancer2::Core::App;
use Dancer2::FileUtils;
use Dancer2::ModuleLoader;

our $AUTHORITY = 'SUKRIA';

# set version in dist.ini now
# but we still need a basic version for
# the tests
$Dancer2::VERSION ||= '0.01'; # 2.0.1

#
# private
#

=head1 DESCRIPTION

This is the main module for the Dancer2 distribution. It contains logic for creating
a new Dancer2 application.

=head1 OVERVIEW

Dancer2 is the new generation lightweight web-framework for Perl. It's a
complete rewrite of L<Dancer> based on L<Moo>.

An application can be as simple as this simple hello world script:

    use Dancer2;
    get '/' => sub { "Hello World" };
    dance;

This doc describes the Dancer2 application core and therefore meant for Dancer2
core developers. If you're a user of Dancer2, you should forget about this and
read the L<Dancer2::Manual>.

You are also welcome to join our mailing list, and we're also on IRC: #dancer
on irc.perl.org.

=cut

=func my $runner=runner();

Returns the current runner. It is of type L<Dancer2::Core::Runner>.

=cut

my $runner;

sub runner {$runner}

=method my $runner=import;

This subroutine does most of the work.

First it imports strict and warnings.

Then it does the following for these import options:

=over 4

=item C<:moose>

No importing of C<before> and C<after> hooks into your namespace. This is to
prevent conflict with L<Moose> et al.

=item C<:tests>

No importing of C<pass> function. This is to prevent conflict with
L<Test::More> et al.

=item C<:syntax>

Imports syntax only instead of treating your code as a script with command line
parameter parsing and built-in web server.

=item C<:script>

Do not process arguments.

=back

It creates a new runner if one does not exist already.

It will then load additional libraries.

Then create a new Dancer2 app, of type L<Dancer2::Core::App>.

Then it will export all the DSL symbols to the caller.

If any additional argument processing is needed, it will be done at this point.

=cut

sub import {
    my ($class,  @args)   = @_;
    my ($caller, $script) = caller;

    strict->import;
    utf8->import;

    my @final_args;
    my $syntax_only = 0;
    my $as_script   = 0;
    foreach (@args) {
        if ($_ eq ':moose') {
            push @final_args, '!before' => 1, '!after' => 1;
        }
        elsif ($_ eq ':tests') {
            push @final_args, '!pass' => 1;
        }
        elsif ($_ eq ':syntax') {
            $syntax_only = 1;
        }
        elsif ($_ eq ':script') {
            $as_script = 1;
        }
        elsif (substr($_, 0, 1) eq '!') {
            push @final_args, $_, 1;
        }
        else {
            push @final_args, $_;
        }
    }

    scalar(@final_args) % 2
      and die
      "parameters to 'use Dancer2' should be one of : 'key => value', ':moose', ':tests', ':script', or !<keyword>, where <keyword> is a DSL keyword you don't want to import";
    my %final_args = @final_args;

    $final_args{dsl} ||= 'Dancer2::Core::DSL';

    # never instantiated the runner, should do it now
    if (not defined $runner) {

        # TODO should support commandline options as well

        $runner = Dancer2::Core::Runner->new(caller => $script,);
    }

    my $local_libdir = Dancer2::FileUtils::path($runner->location, 'lib');
    Dancer2::ModuleLoader->use_lib($local_libdir) if -d $local_libdir;

    # the app object
    my $app = Dancer2::Core::App->new(
        name            => $caller,
        environment     => $runner->environment,
        location        => $runner->location,
        runner_config   => $runner->config,
        postponed_hooks => $runner->postponed_hooks,
    );

    core_debug("binding import method to $caller");
    _set_import_method_to_caller($caller);

    # register the app within the runner instance
    core_debug("binding app to $caller");
    $runner->server->register_application($app);

    core_debug("exporting DSL symbols for $caller");

    # load the DSL, defaulting to Dancer2::Core::DSL
    Dancer2::ModuleLoader->require($final_args{dsl})
      or die "Couldn't require '" . $final_args{dsl} . "'\n";
    my $dsl = $final_args{dsl}->new(app => $app);
    $dsl->export_symbols_to($caller, \%final_args);

#
#    # if :syntax option exists, don't change settings
#    return if $syntax_only;
#
#    $as_script = 1 if $ENV{PLACK_ENV};
#
#    Dancer2::GetOpt->process_args() if !$as_script;
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
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::import"} = $import;
    }
}

=func core_debug

Output a message to STDERR and take further arguments as some data structures using 
L<Data::Dumper>

=cut

sub core_debug {
    my $msg = shift;
    my (@stuff) = @_;
    use Data::Dumper;

    my $vars = @stuff ? Dumper(\@stuff) : '';

    my ($package, $filename, $line) = caller;
    return unless $ENV{DANCER_DEBUG_CORE};

    chomp $msg;
    print STDERR "core: $msg\n$vars";
}

1;
