package Dancer;

use strict;
use warnings;
use Carp;

our $VERSION   = '1.9999_01';
our $AUTHORITY = 'SUKRIA';

# TEMP REMOVE ME WHEN DANCER 2 IS READY
sub core_debug {
    my $msg = shift;
    chomp $msg;
    print "core: $msg\n";
}
# TEMP REMOVE ME WHEN DANCER 2 IS READY

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
    var
    vars
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

# access to the server singleton (and this is the only one singleton you will
# find in Dancer 2, if you wonder).
# will be populated on-the-fly when needed
sub server { }

# start the server
sub start {
    my $server = Dancer->server;
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

sub vars {
    my $app = shift;
    $app->context->buffer;
}

sub var {
    my $app = shift;
    @_ == 2
      ? $app->context->buffer->{$_[0]} = $_[1]
      : $app->context->buffer->{$_[0]};
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

    # look if we already have a server instanciated
    my $server = Dancer->server; 

    # never instanciated the server, should do it now
    if (not defined $server) {
        # TODO : should support multiple servers there, when the config is ready
        $server = Dancer::Core::Server::Standalone->new();

        # now bind that instance to the server symbol, for ever! 
        { no strict 'refs'; no warnings 'redefine';
            *{"Dancer::server"} = sub { $server };
        }
    }

    # the app object
    my $app = Dancer::Core::App->new( name => $caller );

    core_debug "binding app to $caller";
    # bind the app to the caller
    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::dancer_app"} = sub { $app };
    }

    # register the app within the server instance
    $server->register_application($app);

    # compile the DSL symbols to make them receive the $app
    # also, all the symbols meant to be used within a route handler
    # will check that there is a context running. 
    my @global_dsl = qw(
        start dance setting set
        get put post del options
        prefix
    );
    for my $symbol (@EXPORT) {
        my $orig_sub = _get_orig_symbol($symbol);
        my $new_sub  = sub {
            my $caller = caller;
            my $app = $caller->dancer_app;
            
            core_debug "[$caller] running '$symbol' with ".
                join(', ', map { defined $_ ? $_ : 'undef' } @_);
            
            _assert_is_context($symbol, $app)
                unless grep {/^$symbol$/} @global_dsl;
            
            $orig_sub->($app, @_);
        };
        {
            no strict 'refs';
            no warnings 'redefine';
            *{"Dancer::${symbol}"} = $new_sub;
        }
    }
    
    # now we can export them
    $class->export_to_level(1, $class, @final_args);
#
#    # if :syntax option exists, don't change settings
#    return if $syntax_only;
#
#    $as_script = 1 if $ENV{PLACK_ENV};
#
#    Dancer::GetOpt->process_args() if !$as_script;

    # TODO : should be in Dancer::App _init_script_dir($script);
#    Dancer::Config->load;
}

# we have to cache the original symbols, if Dancer is imported more
# than once, it's going to be bogus
my $_orig_dsl_symbols = {};
sub _get_orig_symbol {
    my ($symbol) = @_;
    
    # already saved this one, return it
    return $_orig_dsl_symbols->{$symbol}
        if exists $_orig_dsl_symbols->{$symbol};

    # first time, save the symbol
    my $orig;
    { 
        no strict 'refs';
        $orig = *{"Dancer::${symbol}"}{CODE};
    
        # also bind the original symbol to a private name
        # in order to be able to call it manually from within Dancer.pm
        *{"Dancer::_${symbol}"} = $orig;
    }

    # return the newborn cache version
    return $_orig_dsl_symbols->{$symbol} = $orig;
}

1;
