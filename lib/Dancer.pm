package Dancer;

use strict;
use warnings;
use Carp;

use Dancer::Core::Runner;
use Dancer::Core::App;
use Dancer::Core::Hook;
use Dancer::FileUtils;

our $VERSION   = '1.9999_01';
our $AUTHORITY = 'SUKRIA';

# TEMP REMOVE ME WHEN DANCER 2 IS READY
sub core_debug {
    my $msg = shift;
    chomp $msg;
    print STDERR "core: $msg\n";
}
# TEMP REMOVE ME WHEN DANCER 2 IS READY

use base 'Exporter';

our @EXPORT = qw(
    after
    any
    before
    before_template
    captures
    config
    content_type
    cookie
    cookies
    dance
    debug
    del
    dirname
    engine
    from_json
    get
    header
    headers
    hook
    mime
    options
    path
    post
    prefix
    push_header
    put
    set
    setting
    splat
    start
    app
    false
    halt
    param
    params
    pass
    redirect
    request
    status
    template
    true
    to_json
    var
    vars
    warning
);

#
# Dancer's syntax
#

#
# Handy helpers
#

sub app { shift }

sub debug   { _log(shift, debug   => @_) }
sub warning { _log(shift, warning => @_) }
sub error   { _log(shift, error   => @_) }

sub true  { 1 }
sub false { 0 }

sub dirname { shift and Dancer::FileUtils::dirname(@_) }
sub path    { shift and Dancer::FileUtils::path(@_)    }

sub config {
    my $app = shift;
    my $runner = Dancer->runner;

    return {
        %{ $runner->config },
        %{ $app->config },
    };
}

sub engine {
    my $app = shift;
    my ($name) = @_;

    my $e = _config($app)->{$name};
    croak "No '$name' engine defined" if not defined $e;

    return $e;
}

sub setting {
    my $app = shift;
    my $dancer = Dancer->runner;

    # reader
    if (@_ == 1) {
        # we should ask the app first, and then the runner
        return $app->setting(@_) if $app->has_setting(@_);
        return $dancer->setting(@_);
    }

    # writer: we always write to the app registry, only config files can write
    # into dancer's configuration (which is global as such)
    $app->setting(@_);
}

sub set { goto &_setting }

sub template {
    my $app = shift;
    my $template = _engine($app, 'template');

    $template->context($app->context);
    my $content = $template->process(@_);
    $template->context(undef);

    return $content;
}

sub before_template {
    my $app = shift;
    my $template = _engine($app, 'template');

    $template->add_hook(Dancer::Core::Hook->new(
        name => 'before_template_render',
        code => $_[0],
    ));
}

#
# route handlers & friends
#

sub hook {
    my $app = shift;
    my ($name, $code) = @_;
    
    my $hookable = $app;
    # TODO: better hook dispatching to come
    if ($name =~ /template/) {
        $hookable = _engine($app, 'template');
    }

    $hookable->add_hook(Dancer::Core::Hook->new(name => $name, code => $code));
}

sub before {
    my $app = shift;
    $app->add_hook(Dancer::Core::Hook->new(name => 'before', code => $_[0]));
}

sub after {
    my $app = shift;
    $app->add_hook(Dancer::Core::Hook->new(name => 'after', code => $_[0]));
}

sub prefix {
    my $app = shift;
    @_ == 1
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub halt {
    my $app = shift;
    $app->context->response->is_halted(1);
}

sub get {
    my $app = shift;
    $app->add_route( method => 'get',  regexp => $_[0], code => $_[1] );
    $app->add_route( method => 'head', regexp => $_[0], code => $_[1] );
}

sub post {
    my $app = shift;
    $app->add_route( method => 'post', regexp => $_[0], code => $_[1] );
}

sub any {
    my $app = shift;

    my $methods = $_[0];
    croak "any must be given an ArrayRef of HTTP methods"
        unless ref($methods) eq 'ARRAY';

    for my $method (@{$methods}) {
        $app->add_route(method => $method,
                        regexp => $_[1],
                        code   => $_[2]);
        ($method eq "get") and $app->add_route(method => 'head',
                                               regexp => $_[1],
                                               code   => $_[2]);
    }
}

sub put {
    my $app = shift;
    $app->add_route( method => 'put', regexp => $_[0], code   => $_[1] );
}

sub del {
    my $app = shift;
    $app->add_route( method => 'delete', regexp => $_[0], code   => $_[1] );
}

sub options {
    my $app = shift;
    $app->add_route( method => 'options', regexp => $_[0], code   => $_[1] );
}

#
# Server startup
#

# access to the runner singleton
# will be populated on-the-fly when needed
# this singleton contains anything needed to start the application server
sub runner { }

# start the server
sub start {
    my $app = shift;
    my $dancer = Dancer->runner;
    my $server = $dancer->server;

    $_->finish for @{ $server->apps };

    # update the server config if needed
    my $port = _setting($app, 'server_port');
    my $host = _setting($app, 'server_host');
    my $is_daemon = _setting($app, 'server_is_daemon');

    $server->port($port) if defined $port;
    $server->host($host) if defined $host;
    $server->is_daemon($is_daemon) if defined $is_daemon;
    $server->start;
}
sub dance { goto &_start }

#
# Response alterations
#

sub status {
    my $app = shift;
    $app->context->response->status($_[0]);
}

sub push_header {
    my $app = shift;
    $app->context->response->push_header(@_);
}

sub header {
    my $app = shift;
    $app->context->response->header(@_);
}

sub headers { goto &header };

sub content_type {
    my $app = shift;
    _header($app, 'Content-Type' => _mime($app)->name_or_type($_[0]));
}

sub pass {
    my $app = shift;
    $app->context->response->has_passed(1);
}

#
# Route handler helpers
#

sub request {
    my $app = shift;
    $app->context->request;
}

sub captures {
     my $app = shift;
     $app->context->request->params->{captures};
}

sub splat {
     my $app = shift;
     $app->context->request->params->{splat};
}

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

sub cookies {
    my $app = shift;
    return $app->context->cookies;
}

sub mime {
    my $app = shift;

    # we can be called outside a route (see TestApp.pm for an example)
    if ($app && exists($app->config->{default_mime_type})) {
        runner->mime_type->default($app->config->{default_mime_type});
    } else {
        runner->mime_type->reset_default;
    }
    runner->mime_type
}

sub cookie {
    my $app = shift;

    # reader
    return $app->context->cookies->{$_[0]} if @_ == 1;

    # writer
    my ($name, $value, %options) = @_;
    my $c = Dancer::Core::Cookie->new(name => $name, value => $value, %options);
    $app->context->response->push_header('Set-Cookie' => $c->to_header);
}

#
# engines
#

sub from_json {
    my $app = shift;
    require 'Dancer/Serializer/JSON.pm';
    Dancer::Serializer::JSON::from_json(@_);
}

sub to_json {
    my $app = shift;
    require 'Dancer/Serializer/JSON.pm';
    Dancer::Serializer::JSON::to_json(@_);
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

    # look if we already have a runner instance living
    my $runner = Dancer->runner;

    # never instanciated the runner, should do it now
    if (not defined $runner) {
        # TODO should support commandline options as well

        $runner = Dancer::Core::Runner->new(
            caller => $script,
        );

        # now bind that instance to the runner symbol, for ever!
        { no strict 'refs'; no warnings 'redefine';
            *{"Dancer::runner"} = sub { $runner };
        }
    }

    # the app object
    my $app = Dancer::Core::App->new(
        name          => $caller,
        location      => runner->location,
        runner_config => runner->config,
    );

    core_debug "binding app to $caller";
    # bind the app to the caller
    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::dancer_app"} = sub { $app };
    }

    # register the app within the runner instance
    $runner->server->register_application($app);

    my @global_dsl = qw(
        after
        any
        before
        before_template
        config
        content_type
        dance
        dirname
        debug
        del
        error
        false
        from_json
        to_json
        from_yaml
        to_yaml
        from_dumper
        to_dumper
        header
        headers
        hook
        get
        mime
        options
        path
        post
        prefix
        push_header
        put
        set
        setting
        start
        true
        warning
    );

    # compile the DSL symbols to make them receive the $app
    # also, all the symbols meant to be used within a route handler
    # will check that there is a context running.
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

sub _log {
    my $app = shift;
    my $level = shift;

    my $logger = $app->config->{logger};
    croak "No logger defined" if ! defined $logger;

    $logger->$level(@_);
}

1;
