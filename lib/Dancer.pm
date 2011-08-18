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
    dance
    get
    header
    param
    params
    prefix
    redirect
    start
    status
);

#
# Dancer's syntax
#

#
# route handlers & friends
#

sub prefix { 
    my $app = shift;
    @_ == 1 
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub get { 
    my $app = shift;
    $app->add_route(method => 'get',  regexp => $_[0], code => $_[1]);
    $app->add_route(method => 'head', regexp => $_[0], code => $_[1]);
}

sub post {
    my $app = shift;
    $app->add_route(
        method => 'post',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub put {
    my $app = shift;
    $app->add_route(
        method => 'put',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub del {
    my $app = shift;
    $app->add_route(
        method => 'delete',
        regexp => $_[0],
        code   => $_[1]
    );
}

sub options {
    my $app = shift;
    $app->add_route(
        method => 'options',
        regexp => $_[0],
        code   => $_[1]
    );
}

#
# Server startup
#

sub start {
    my $app = shift;
    my $server = Dancer::Core::Server::Standalone->new(app => $app);
    $server->start;
}
sub dance { goto &start }

#
# Response alterations
#

sub status { 
    my $app = shift;
    $app->context->response->{status} = $_[0];
}

sub header {
    my $app = shift;
    push @{ $app->context->response->{headers} }, @_;
}

sub content_type {
    my $app = shift;
    _header($app, 'Content-Type' => $_[0]);
}

#
# Route handler helpers
#

sub params {
    my $app = shift;
    $app->context->request->params(@_);
}

sub param { 
    my $app = shift;
    _params($app)->{$_[0]};
}

sub redirect {
    my $app = shift;
    my ($destination, $status) = @_;

    # RFC 2616 requires an absolute URI with a scheme,
    # turn the URI into that if it needs it

    # Scheme grammar as defined in RFC 2396
    #  scheme = alpha *( alpha | digit | "+" | "-" | "." )
    my $scheme_re = qr{ [a-z][a-z0-9\+\-\.]* }ix;
    if ($destination !~ m{^ $scheme_re : }x) {
        my $request = $app->context->request;
        $destination = $request->uri_for($destination, {}, 1);
    }

    # now we just have to wrap status and header:
    _status($app, $status || 302);
    _header($app, 'Location' => $destination);
}

#
# private
#

sub _assert_is_context {
    my ($symbol, $app) = @_;

    croak "Function '$symbol' must be called from a route handler"
      unless defined $app->context;
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

    # compile the DSL symbols to make them receive the $app
    # also, all the symbols meant to be used within a route handler
    # will check that there is a context running. 
    my @global_dsl = qw(
        start dance setting set
        get put post del options
        prefix
    );
    for my $symbol (@EXPORT) {
        {
            no strict 'refs';
            no warnings 'redefine';

            # save the original symbol first
            # we keep the orig symbol with a prefix '_' 
            # that way we can use it within Dancer
            my $orig = *{"Dancer::${symbol}"}{CODE};
            *{"Dancer::_${symbol}"} = $orig;

            # then alter it with our black magic
            *{"Dancer::${symbol}"} = sub {
                my $app = caller->dancer_app;

                _assert_is_context($symbol, $app)
                    unless grep {/^$symbol$/} @global_dsl;
                 
                $orig->($app, @_);
            };
        }
    }
    
    # now we can export them
    $class->export_to_level(1, $class, @final_args);

    # if :syntax option exists, don't change settings
    return if $syntax_only;

    $as_script = 1 if $ENV{PLACK_ENV};

#    Dancer::GetOpt->process_args() if !$as_script;

    # TODO : should be in Dancer::App _init_script_dir($script);
#    Dancer::Config->load;
}

1;
