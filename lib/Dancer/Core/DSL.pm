package Dancer::Core::DSL;

use Data::Dumper;
use Dancer::Core::Hook;
use Dancer::FileUtils;
use Moo;

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
        context
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
        response
        send_file
        session
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
            $map{$keyword} = sub { 
                core_debug("[".$self->app->name."] -> $keyword(".join(', ', @_).")");
                $self->$keyword(@_);
            };
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

sub config { shift->app->settings }

sub engine { shift->app->engine(@_) }

sub setting { shift->app->setting(@_) }

sub set { shift->setting(@_) }

sub template { shift->app->template(@_) }

sub session { shift->app->session(@_) }

sub send_file { shift->app->send_file(@_) }

#
# route handlers & friends
#

sub hook {
    my ($self, $name, $code) = @_;
    $self->app->add_hook(Dancer::Core::Hook->new(name => $name, code => $code));
}

sub prefix {
    my $app = shift->app;
    @_ == 1
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub halt { shift->app->context->response->halt }

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
    my ($self, $methods, @params) = @_;
    my $app = $self->app;

    croak "any must be given an ArrayRef of HTTP methods"
        unless ref($methods) eq 'ARRAY';

    for my $method (@{$methods}) {
        $self->$method(@params);
    }
}

sub put {
    my $app = shift->app;
    $app->add_route( method => 'put', regexp => $_[0], code   => $_[1] );
}

sub del { shift->delete(@_) }

sub delete {
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
sub start { shift->runner->start }

sub dance { shift->start(@_) }

#
# Response alterations
#

sub status { shift->response->status(@_) }
sub push_header { shift->response->push_header(@_) }
sub header { shift->response->header(@_) }
sub headers { shift->response->header(@_) }
sub content_type { shift->response->content_type(@_) }
sub pass { shift->response->pass }

#
# Route handler helpers
#

sub context { shift->app->context }

sub request { shift->context->request }

sub response { shift->context->response }

sub upload { shift->request->upload(@_) }

sub captures { shift->request->captures }

sub uri_for { shift->request->uri_for(@_) }

sub splat { shift->request->splat }

sub params { shift->request->params }

sub param { shift->request->param(@_) }

sub redirect { shift->context->redirect(@_) }

sub forward { shift->request->forward(@_) }

sub vars { shift->context->vars }
sub var { shift->context->var(@_) }

sub cookies { shift->context->cookies }

sub mime {
    my $self = shift;
    if ($self->app) {
        return $self->app->mime_type
    } else {
        my $runner = $self->runner;
        $runner->mime_type->reset_default;
        return $runner->mime_type;
    }
}

sub cookie { shift->context->cookie(@_) }

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

sub log { shift->app->log(@_) }

sub core_debug {
    my $msg = shift;
    return unless $ENV{DANCER_DEBUG_CORE};

    chomp $msg;
    print STDERR "core: $msg\n";
}

1;
