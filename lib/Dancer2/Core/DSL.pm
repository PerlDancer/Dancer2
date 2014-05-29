# ABSTRACT: Dancer2's Domain Specific Language (DSL)

package Dancer2::Core::DSL;

use Moo;
use Carp;
use Class::Load 'load_class';
use Dancer2::Core::Hook;
use Dancer2::Core::Error;
use Dancer2::FileUtils;

with 'Dancer2::Core::Role::DSL';

sub dsl_keywords {

    # the flag means : 1 = is global, 0 = is not global. global means can be
    # called from anywhere. not global means must be called from within a route
    # handler
    {   any                  => { is_global => 1 },
        app                  => { is_global => 1 },
        captures             => { is_global => 0 },
        config               => { is_global => 1 },
        content_type         => { is_global => 0 },
        context              => { is_global => 0 },
        cookie               => { is_global => 0 },
        cookies              => { is_global => 0 },
        dance                => { is_global => 1 },
        dancer_app           => { is_global => 1 },
        dancer_version       => { is_global => 1 },
        dancer_major_version => { is_global => 1 },
        debug                => { is_global => 1 },
        del                  => { is_global => 1 },
        dirname              => { is_global => 1 },
        dsl                  => { is_global => 1 },
        engine               => { is_global => 1 },
        error                => { is_global => 1 },
        false                => { is_global => 1 },
        forward              => { is_global => 0 },
        from_dumper          => { is_global => 1 },
        from_json            => { is_global => 1 },
        from_yaml            => { is_global => 1 },
        get                  => { is_global => 1 },
        halt                 => { is_global => 0 },
        header               => { is_global => 0 },
        headers              => { is_global => 0 },
        hook                 => { is_global => 1 },
        info                 => { is_global => 1 },
        log                  => { is_global => 1 },
        mime                 => { is_global => 1 },
        options              => { is_global => 1 },
        param                => { is_global => 0 },
        params               => { is_global => 0 },
        pass                 => { is_global => 0 },
        patch                => { is_global => 1 },
        path                 => { is_global => 1 },
        post                 => { is_global => 1 },
        prefix               => { is_global => 1 },
        push_header          => { is_global => 0 },
        put                  => { is_global => 1 },
        redirect             => { is_global => 0 },
        request              => { is_global => 0 },
        response             => { is_global => 0 },
        runner               => { is_global => 1 },
        send_error           => { is_global => 0 },
        send_file            => { is_global => 0 },
        session              => { is_global => 0 },
        set                  => { is_global => 1 },
        setting              => { is_global => 1 },
        splat                => { is_global => 0 },
        start                => { is_global => 1 },
        status               => { is_global => 0 },
        template             => { is_global => 0 },
        to_dumper            => { is_global => 1 },
        to_json              => { is_global => 1 },
        to_yaml              => { is_global => 1 },
        true                 => { is_global => 1 },
        upload               => { is_global => 0 },
        uri_for              => { is_global => 0 },
        var                  => { is_global => 0 },
        vars                 => { is_global => 0 },
        warning              => { is_global => 1 },
    };
}

sub dancer_app     { shift->app }
sub dancer_version { Dancer2->VERSION }

sub dancer_major_version {
    return ( split /\./, dancer_version )[0];
}

sub debug   { shift->log( debug   => @_ ) }
sub info    { shift->log( info    => @_ ) }
sub warning { shift->log( warning => @_ ) }
sub error   { shift->log( error   => @_ ) }

sub true  {1}
sub false {0}

sub dirname { shift and Dancer2::FileUtils::dirname(@_) }
sub path    { shift and Dancer2::FileUtils::path(@_) }


sub config { shift->app->settings }

sub engine { shift->app->engine(@_) }

=func setting

Lets you define settings and access them:
    setting('foo' => 42);
    setting('foo' => 42, 'bar' => 43);
    my $foo=setting('foo');

If settings were defined returns number of settings.

=cut

sub setting { shift->app->setting(@_) }

=func set ()

alias for L<setting>:
    set('foo' => '42');
    my $port=set('port');

=cut

sub set { shift->setting(@_) }

sub template { shift->app->template(@_) }

sub session { shift->app->session(@_) }

sub send_file { shift->app->send_file(@_) }

#
# route handlers & friends
#

sub hook {
    my ( $self, $name, $code ) = @_;
    $self->app->add_hook(
        Dancer2::Core::Hook->new( name => $name, code => $code ) );
}

sub prefix {
    my $app = shift->app;
    @_ == 1
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub halt { shift->context->halt }

sub _route_parameters {
    my ( $regexp, $code, $options );
    ( scalar @_ == 3 )
      ? ( ( $regexp, $code, $options ) = ( $_[0], $_[2], $_[1] ) )
      : ( ( $regexp, $code, $options ) = ( $_[0], $_[1], {} ) );
    return ( $regexp, $code, $options );
}

sub get {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    for my $method (qw/get head/) {
        $app->add_route(
            method  => $method,
            regexp  => $regexp,
            code    => $code,
            options => $options
        );
    }
}

sub post {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    $app->add_route(
        method  => 'post',
        regexp  => $regexp,
        code    => $code,
        options => $options
    );
}

sub any {
    my ( $self, $methods, @params ) = @_;
    my $app = $self->app;

    if ($methods) {
        if ( ref($methods) ne 'ARRAY' ) {
            unshift @params, $methods;
            $methods = [qw(get post put del options patch)];
        }
    }

    for my $method ( @{$methods} ) {
        $self->$method(@params);
    }
}

sub put {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    $app->add_route(
        method  => 'put',
        regexp  => $regexp,
        code    => $code,
        options => $options,
    );
}

sub del {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    $app->add_route(
        method  => 'delete',
        regexp  => $regexp,
        code    => $code,
        options => $options,
    );
}

sub options {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    $app->add_route(
        method  => 'options',
        regexp  => $regexp,
        code    => $code,
        options => $options,
    );
}

sub patch {
    my $app = shift->app;

    my ( $regexp, $code, $options ) = _route_parameters(@_);
    $app->add_route(
        method  => 'patch',
        regexp  => $regexp,
        code    => $code,
        options => $options,
    );
}

#
# Server startup
#

# access to the runner singleton
# will be populated on-the-fly when needed
# this singleton contains anything needed to start the application server
sub runner { Dancer2->runner }

# start the server
sub start { shift->runner->start }

sub dance { shift->start(@_) }

#
# Response alterations
#

sub status       { shift->response->status(@_) }
sub push_header  { shift->response->push_header(@_) }
sub header       { shift->response->header(@_) }
sub headers      { shift->response->header(@_) }
sub content_type { shift->response->content_type(@_) }
sub pass         { shift->context->pass }

#
# Route handler helpers
#

sub context { shift->app->context }

sub request { shift->app->request }

sub response { shift->context->response }

sub upload { shift->request->upload(@_) }

sub captures { shift->request->captures }

sub uri_for { shift->request->uri_for(@_) }

sub splat { shift->request->splat }

sub params { shift->request->params(@_) }

sub param { shift->request->param(@_) }

sub redirect { shift->context->redirect(@_) }

sub forward {
    my $self = shift;
    $self->request->forward($self->context, @_);
}

sub vars { shift->request->vars }
sub var  { shift->request->var(@_) }

sub cookies { shift->request->cookies }

sub mime {
    my $self = shift;
    if ( $self->app ) {
        return $self->app->mime_type;
    }
    else {
        my $runner = $self->runner;
        $runner->mime_type->reset_default;
        return $runner->mime_type;
    }
}

sub cookie { shift->context->cookie(@_) }

sub send_error {
    my ( $self, $message, $status ) = @_;

    my $serializer = $self->app->engine('serializer');
    my $x = Dancer2::Core::Error->new(
          message    => $message,
          app        => $self->app,
        ( status     => $status     ) x !!$status,
        ( serializer => $serializer ) x !!$serializer,
    )->throw;

    # return if there is a with_return coderef
    $self->context->with_return->($x)
      if $self->context->has_with_return;

    return $x;
}

#
# engines
#

sub from_json {
    shift; # remove first element
    require 'Dancer2/Serializer/JSON.pm';
    Dancer2::Serializer::JSON::from_json(@_);
}

sub to_json {
    shift; # remove first element
    require 'Dancer2/Serializer/JSON.pm';
    Dancer2::Serializer::JSON::to_json(@_);
}

sub from_yaml {
    shift; # remove first element
    require 'Dancer2/Serializer/YAML.pm';
    Dancer2::Serializer::YAML::from_yaml(@_);
}

sub to_yaml {
    shift; # remove first element
    require 'Dancer2/Serializer/YAML.pm';
    Dancer2::Serializer::YAML::to_yaml(@_);
}

sub from_dumper {
    shift; # remove first element
    require 'Dancer2/Serializer/Dumper.pm';
    Dancer2::Serializer::Dumper::from_dumper(@_);
}

sub to_dumper {
    shift; # remove first element
    require 'Dancer2/Serializer/Dumper.pm';
    Dancer2::Serializer::Dumper::to_dumper(@_);
}

sub log { shift->app->log(@_) }

=head1 SEE ALSO

L<http://advent.perldancer.org/2010/18>

=cut

1;
