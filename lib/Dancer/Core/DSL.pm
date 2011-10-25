package Dancer::Core::DSL;

use Data::Dumper;
use Dancer::Core::Hook;
use Dancer::FileUtils;
use Moo;

BEGIN {
    # Moo doesn't have an option to not export these and we need to
    # define our own. This is my fault. -- mst
    no strict 'refs';
    my $pkg = \%{__PACKAGE__.'::'};
    delete $pkg->{before};
    delete $pkg->{after};
}

has app => (is => 'ro', required => 1);

use Carp;

{
    my %keywords = map +($_ => 1), qw(
        after
        any
        app
        before
        before_template
        captures
        config
        content_type
        cookie
        cookies
        dance
        dancer_app
        debug
        del
        dirname
        engine
        error
        false
        forward
        from_json
        from_yaml
        from_dumper
        get
        halt
        header
        headers
        hook
        mime
        options
        param
        params
        pass
        path
        post
        prefix
        push_header
        put
        redirect
        request
        send_file
        set
        setting
        splat
        start
        status
        template
        to_json
        to_yaml
        to_dumper
        true
        upload
        uri_for
        var
        vars
        warning
    );

    $keywords{$_} = 1 for qw(
        after
        any
        before
        before_template
        config
        content_type
        dance
        dancer_app
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
        uri_for
        true
        warning
    );

    sub _keyword_list { keys %keywords }
    sub _is_global_keyword { $keywords{$_[1]} }
}

sub construct_export_map {
    my ($self) = @_;
    my %map;
    foreach my $keyword ($self->_keyword_list) {
        if ($self->_is_global_keyword($keyword)) {
            $map{$keyword} = sub { $self->$keyword(@_) };
        } else {
            $map{$keyword} = sub {
                croak "Function '$keyword' must be called from a route handler"
                    unless defined $self->app->context;
                $self->$keyword(@_);
            }
        }
    }
    return \%map;
}

#
# Dancer's syntax
#

#
# Handy helpers
#

sub dancer_app { shift->app }

sub debug   { shift->log(debug   => @_) }
sub warning { shift->log(warning => @_) }
sub error   { shift->log(error   => @_) }

sub true  { 1 }
sub false { 0 }

sub dirname { shift and Dancer::FileUtils::dirname(@_) }
sub path    { shift and Dancer::FileUtils::path(@_)    }

sub config {
    my ($self) = @_;

    return $self->app->settings;
}

sub engine {
    my ($self, $name) = @_;

    my $e = $self->config->{$name};
    croak "No '$name' engine defined" if not defined $e;

    return $e;
}

sub setting {
    shift->app->setting(@_)
}

sub set { shift->setting(@_) }

sub template {
    my ($self) = @_;
    my $template = $self->engine('template');

    $template->context($self->app->context);
    my $content = $template->process(@_);
    $template->context(undef);

    return $content;
}

sub before_template {
    my ($self, $code) = @_;
    my $template = $self->engine('template');

    $template->add_hook(Dancer::Core::Hook->new(
        name => 'before_template_render',
        code => $code,
    ));
}

sub send_file {
    my ($self, $path, %options) = @_;
    my $app = $self->app;
    my $env = $app->context->env;

    ($options{'streaming'} && ! $env->{'psgi.streaming'}) and
        croak "Streaming is not supported on this server.";

    (exists $options{'content_type'}) and
        $self->header('Content-Type' => $options{content_type});

    (exists $options{filename}) and
        $self->header(
            'Content-Disposition' =>
                "attachment; filename=\"$options{filename}\""
        );
    
    # if we're given a SCALAR reference, we're going to send the data
    # pretending it's a file (on-the-fly file sending)
    (ref($path) eq 'SCALAR') and
        return $$path;

    my $file_handler = Dancer::Handler::File->new(
        app => $app,
        public_dir => ($options{system_path} ? File::Spec->rootdir : undef ),
    ); 

    for my $h (keys %{ $app->route_handlers->{File}->hooks} ) {
        my $hooks = $app->route_handlers->{File}->hooks->{$h};
        $file_handler->replace_hooks($h, $hooks);
    }

    $app->context->request->path_info($path);
    return $file_handler->code->($app->context, $app->prefix);
    
    # TODO Streaming support
}

#
# route handlers & friends
#

sub hook {
    my ($self, $name, $code) = @_;

    my $template;
    eval { $template = $self->engine('template') };

    my $hookables = {
        'Dancer::Core::App'            => $self->app,
        'Dancer::Core::Role::Template' => $template, 
        'Dancer::Handler::File' => $self->app->route_handlers->{File},
    };

    # a map to find which class owns a hook
    my $hookable_classes_by_name = {};
    foreach my $class (keys %{ $hookables }) {
        eval "use $class";
        croak "Unable to load class: $class : $@" if $@;

        $hookable_classes_by_name = { 
            %{$hookable_classes_by_name},
            map { $_ => $class } $class->supported_hooks
        };
    }
    
    my $hookable = $hookables->{ $hookable_classes_by_name->{$name} };
    (! defined $hookable) and
        croak "Unsupported hook `$name'";

    $hookable->add_hook(Dancer::Core::Hook->new(name => $name, code => $code));
}

sub before {
    my $app = shift->app;
    $app->add_hook(Dancer::Core::Hook->new(name => 'before', code => $_[0]));
}

sub after {
    my $app = shift->app;
    $app->add_hook(Dancer::Core::Hook->new(name => 'after', code => $_[0]));
}

sub prefix {
    my $app = shift->app;
    @_ == 1
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub halt {
    my $app = shift->app;
    $app->context->response->is_halted(1);
}

sub get {
    my $app = shift->app;
    $app->add_route( method => 'get',  regexp => $_[0], code => $_[1] );
    $app->add_route( method => 'head', regexp => $_[0], code => $_[1] );
}

sub post {
    my $app = shift->app;
    $app->add_route( method => 'post', regexp => $_[0], code => $_[1] );
}

sub any {
    my $app = shift->app;

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
    my $app = shift->app;
    $app->add_route( method => 'put', regexp => $_[0], code   => $_[1] );
}

sub del {
    my $app = shift->app;
    $app->add_route( method => 'delete', regexp => $_[0], code   => $_[1] );
}

sub options {
    my $app = shift->app;
    $app->add_route( method => 'options', regexp => $_[0], code   => $_[1] );
}

#
# Server startup
#

# access to the runner singleton
# will be populated on-the-fly when needed
# this singleton contains anything needed to start the application server
sub runner { Dancer->runner }

# start the server
sub start {
    my ($self) = @_;
    my $dancer = $self->runner;
    my $server = $dancer->server;

    $_->finish for @{ $server->apps };

    # update the server config if needed
    my $port = $self->setting('server_port');
    my $host = $self->setting('server_host');
    my $is_daemon = $self->setting('server_is_daemon');

    $server->port($port) if defined $port;
    $server->host($host) if defined $host;
    $server->is_daemon($is_daemon) if defined $is_daemon;
    $server->start;
}
sub dance { shift->start(@_) }

#
# Response alterations
#

sub status {
    my $app = shift->app;
    $app->context->response->status($_[0]);
}

sub push_header {
    my $app = shift->app;
    $app->context->response->push_header(@_);
}

sub header {
    my $app = shift->app;
    $app->context->response->header(@_);
}

sub headers { shift->header(@_) }

sub content_type {
    my ($self, $type) = @_;
    $self->header('Content-Type' => $self->mime->name_or_type($type));
}

sub pass {
    my $app = shift->app;
    $app->context->response->has_passed(1);
}

#
# Route handler helpers
#

sub request {
    my $app = shift->app;
    $app->context->request;
}

sub upload { 
    my $app = shift->app;
    $app->context->request->upload(@_);
}

sub captures {
     my $app = shift->app;
     $app->context->request->params->{captures};
}

sub uri_for {
    my $app = shift->app;
    $app->context->request->uri_for(@_);
}

sub splat {
     my $app = shift->app;
     @{ $app->context->request->params->{splat} || [] };
}

sub params {
    my $app = shift->app;
    $app->context->request->params(@_);
}

sub param {
    my $self = shift;
    $self->params->{$_[0]};
}

sub redirect {
    my ($self, $destination, $status) = @_;

    # RFC 2616 requires an absolute URI with a scheme,
    # turn the URI into that if it needs it

    # Scheme grammar as defined in RFC 2396
    #  scheme = alpha *( alpha | digit | "+" | "-" | "." )
    my $scheme_re = qr{ [a-z][a-z0-9\+\-\.]* }ix;
    if ($destination !~ m{^ $scheme_re : }x) {
        my $request = $self->app->context->request;
        $destination = $request->uri_for($destination, {}, 1);
    }

    # now we just have to wrap status and header:
    $self->status($status || 302);
    $self->header('Location' => $destination);
}

sub forward {
    my $app = shift->app;
    my ($url, $params, $options) = @_;
    
    my $req = Dancer::Core::Request->forward(
        $app->context->request,
        { to_url => $url, params => $params, options => $options},
    );
    Dancer->runner->server->dispatcher->dispatch($req->env, $req)->content;
}

sub vars {
    my $app = shift->app;
    $app->context->buffer;
}

sub var {
    my $app = shift->app;
    @_ == 2
      ? $app->context->buffer->{$_[0]} = $_[1]
      : $app->context->buffer->{$_[0]};
}

sub cookies {
    my $app = shift->app;
    return $app->context->cookies;
}

sub mime {
    my ($self) = @_;
    my ($app, $runner) = ($self->app, $self->runner);

    # we can be called outside a route (see TestApp.pm for an example)
    if ($app && exists($app->config->{default_mime_type})) {
        $runner->mime_type->default($app->config->{default_mime_type});
    } else {
        $runner->mime_type->reset_default;
    }
    $runner->mime_type
}

sub cookie {
    my $app = shift->app;

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
    my $app = shift->app;
    require 'Dancer/Serializer/JSON.pm';
    Dancer::Serializer::JSON::from_json(@_);
}

sub to_json {
    my $app = shift->app;
    require 'Dancer/Serializer/JSON.pm';
    Dancer::Serializer::JSON::to_json(@_);
}

sub from_yaml {
    my $app = shift->app;
    require 'Dancer/Serializer/YAML.pm';
    Dancer::Serializer::YAML::from_yaml(@_);
}

sub to_yaml {
    my $app = shift->app;
    require 'Dancer/Serializer/YAML.pm';
    Dancer::Serializer::YAML::to_yaml(@_);
}

sub from_dumper {
    my $app = shift->app;
    require 'Dancer/Serializer/Dumper.pm';
    Dancer::Serializer::Dumper::from_dumper(@_);
}

sub to_dumper {
    my $app = shift->app;
    require 'Dancer/Serializer/Dumper.pm';
    Dancer::Serializer::Dumper::to_dumper(@_);
}


sub log {
    my $app = shift->app;
    my $level = shift;

    my $logger = $app->config->{logger};
    croak "No logger defined" if ! defined $logger;

    $logger->$level(@_);
}

sub core_debug {
    my $msg = shift;
    return unless $ENV{DANCER_DEBUG_CORE};

    chomp $msg;
    print STDERR "core: $msg\n";
}

1;
