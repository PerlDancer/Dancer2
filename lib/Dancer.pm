package Dancer;

use strict;
use warnings;
use Carp;

our $VERSION   = '1.9999_01';
our $AUTHORITY = 'SUKRIA';

use Dancer::Core::App;
use Dancer::Core::Server::Standalone;

use base 'Exporter';
our @EXPORT = qw(
    get
    start
    status
    params
    param
    header
    prefix
    dance
);

# Dancer's syntax

sub prefix { 
    @_ == 1 
      ? (caller)->dancer_app->prefix(@_)
      : (caller)->dancer_app->lexical_prefix(@_);
}

sub get { 
    my $caller = caller;
    $caller->dancer_app->add_route(method => 'get',  regexp => $_[0], code => $_[1]);
    $caller->dancer_app->add_route(method => 'head', regexp => $_[0], code => $_[1]);
}

sub post {
    (caller)->dancer_app->add_route(
        method => 'post',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub put {
    (caller)->dancer_app->add_route(
        method => 'put',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub del {
    (caller)->dancer_app->add_route(
        method => 'delete',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub options {
    (caller)->dancer_app->add_route(
        method => 'options',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub start {
    my $caller = caller;
    my $app = $caller->dancer_app;
    my $server = Dancer::Core::Server::Standalone->new(app => $app);
    $server->start;
}

sub status { 
    my $app = (caller)->dancer_app;
    _assert_is_running_context($app);
    $app->running_context->response_attributes->{status} = $_[0];
}

sub header {
    my $app = (caller)->dancer_app;
    _assert_is_running_context($app);
    push @{ $app->running_context->response_attributes->{headers} }, @_;
}

sub content_type {
    my $app = (caller)->dancer_app;
    _assert_is_running_context($app);
    push @{ $app->running_context->response_attributes->{headers} }, 
        'Content-Type' => $_[0] ;
}

sub params {
    my $app = (caller)->dancer_app;
    _assert_is_running_context($app);
    $app->running_context->request->params(@_);
}

sub param { 
    my $app = (caller)->dancer_app;
    _assert_is_running_context($app);
    $app->running_context->request->params->{$_[0]};
}

sub dance { goto &start }

# private

sub _assert_is_running_context {
    my ($app) = @_;
    my $subroutine = (caller(1))[3];

    croak "Function '$subroutine' must be called from a route handler"
      unless defined $app->running_context;
}

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

    # the app object
    my $app = Dancer::Core::App->new( name => $caller );

    # bind the app to the caller
    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::dancer_app"} = sub { $app };
    }

    $class->export_to_level(1, $class, @final_args);

    # if :syntax option exists, don't change settings
    return if $syntax_only;

    $as_script = 1 if $ENV{PLACK_ENV};

#    Dancer::GetOpt->process_args() if !$as_script;

    # TODO : should be in Dancer::App _init_script_dir($script);
#    Dancer::Config->load;
}


1;
