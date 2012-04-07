# ABSTRACT: TODO

package Dancer;

use strict;
use warnings;
use Carp;

use Data::Dumper;
use Dancer::Core::Runner;
use Dancer::Core::App;
use Dancer::Core::DSL;
use Dancer::FileUtils;

our $VERSION   = '2.000000_01';
$VERSION = eval $VERSION;
our $AUTHORITY = 'SUKRIA';

#
# private
#

my $runner;

sub runner { $runner }

sub import {
    my ($class, @args) = @_;
    my ($caller, $script) = caller;

    strict->import;
    utf8->import;

    my @final_args;
    my $syntax_only = 0;
    my $as_script   = 0;
    foreach (@args) {
        if ( $_ eq ':moose' ) {
            push @final_args, '!before', '!after';
        }
        elsif ( $_ eq ':tests' ) {
            push @final_args, '!pass';
        }
        elsif ( $_ eq ':syntax' ) {
            $syntax_only = 1;
        }
        elsif ($_ eq ':script') {
            $as_script = 1;
        } else {
            push @final_args, $_;
        }
    }

    # never instanciated the runner, should do it now
    if (not defined $runner) {
        # TODO should support commandline options as well

        $runner = Dancer::Core::Runner->new(
            caller => $script,
        );
    }

    my $local_libdir = Dancer::FileUtils::path($runner->location, 'lib');
    _use_lib($local_libdir) if -d $local_libdir;

    # the app object
    my $app = Dancer::Core::App->new(
        name            => $caller,
        environment     => $runner->environment,
        location        => $runner->location,
        runner_config   => $runner->config,
        postponed_hooks => $runner->postponed_hooks,
    );

    core_debug("binding app to $caller");

    # register the app within the runner instance
    $runner->server->register_application($app);

    my $dsl = Dancer::Core::DSL->new(app => $app);
    $dsl->export_symbols_to($caller);

#
#    # if :syntax option exists, don't change settings
#    return if $syntax_only;
#
#    $as_script = 1 if $ENV{PLACK_ENV};
#
#    Dancer::GetOpt->process_args() if !$as_script;
}

sub _use_lib {
    my (@args) = @_;

    use lib;
    local $@;
    lib->import(@args);
    my $error = $@;
    $error and return wantarray ? (0, $error) : 0;
    return 1;
}

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
