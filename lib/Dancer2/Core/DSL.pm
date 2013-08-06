# ABSTRACT: Dancer2's Domain Specific Language (DSL)

package Dancer2::Core::DSL;

use Moo;
use Dancer2::Core::Hook;
use Dancer2::Core::Error;
use Dancer2::FileUtils;
use Dancer2::ModuleLoader;
use Carp;

with 'Dancer2::Core::Role::DSL';

sub dsl_keywords {

    # the flag means : 1 = is global, 0 = is not global. global means can be
    # called from anywhere. not global means must be called from within a route
    # handler
    [   [ any                  => 1 ],
        [ app                  => 1 ],
        [ captures             => 0 ],
        [ config               => 1 ],
        [ content_type         => 0 ],
        [ context              => 0 ],
        [ cookie               => 0 ],
        [ cookies              => 0 ],
        [ dance                => 1 ],
        [ dancer_app           => 1 ],
        [ dancer_version       => 1 ],
        [ dancer_major_version => 1 ],
        [ debug                => 1 ],
        [ del                  => 1 ],
        [ dirname              => 1 ],
        [ dsl                  => 1 ],
        [ engine               => 1 ],
        [ error                => 1 ],
        [ false                => 1 ],
        [ forward              => 0 ],
        [ from_dumper          => 1 ],
        [ from_json            => 1 ],
        [ from_yaml            => 1 ],
        [ get                  => 1 ],
        [ halt                 => 0 ],
        [ header               => 0 ],
        [ headers              => 0 ],
        [ hook                 => 1 ],
        [ info                 => 1 ],
        [ load_app             => 1 ],
        [ log                  => 1 ],
        [ mime                 => 1 ],
        [ options              => 1 ],
        [ param                => 0 ],
        [ params               => 0 ],
        [ pass                 => 0 ],
        [ patch                => 1 ],
        [ path                 => 1 ],
        [ post                 => 1 ],
        [ prefix               => 1 ],
        [ push_header          => 0 ],
        [ put                  => 1 ],
        [ redirect             => 0 ],
        [ request              => 0 ],
        [ response             => 0 ],
        [ runner               => 1 ],
        [ send_error           => 0 ],
        [ send_file            => 0 ],
        [ session              => 0 ],
        [ set                  => 1 ],
        [ setting              => 1 ],
        [ splat                => 0 ],
        [ start                => 1 ],
        [ status               => 0 ],
        [ template             => 0 ],
        [ to_dumper            => 1 ],
        [ to_json              => 1 ],
        [ to_yaml              => 1 ],
        [ true                 => 1 ],
        [ upload               => 0 ],
        [ uri_for              => 0 ],
        [ var                  => 0 ],
        [ vars                 => 0 ],
        [ warning              => 1 ],
    ];
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

sub load_app {
    my ( $self, $app_name, %options ) = @_;

    # set the application
    my ( $res, $error ) = Dancer2::ModuleLoader->load($app_name);
    $res or croak "Unable to load application \"$app_name\" : $error";

    croak "$app_name is not a Dancer2 application"
      if !$app_name->can('dancer_app');
    my $app = $app_name->dancer_app;

# FIXME not working yet
}


sub prefix {
    my $app = shift->app;
    @_ == 1
      ? $app->prefix(@_)
      : $app->lexical_prefix(@_);
}

sub halt { shift->app->context->response->halt }

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
sub pass         { shift->response->pass }

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

sub forward {
    my $self = shift;
    $self->request->forward($self->context, @_);
}

sub vars { shift->context->vars }
sub var  { shift->context->var(@_) }

sub cookies { shift->context->cookies }

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

    my $x = Dancer2::Core::Error->new(
        message => $message,
        context => $self->app->context,
        ( status => $status ) x !!$status,
    )->throw;

    $x;
}

#
# engines
#

sub from_json {
    my $app = shift->app;
    require 'Dancer2/Serializer/JSON.pm';
    Dancer2::Serializer::JSON::from_json(@_);
}

sub to_json {
    my $app = shift->app;
    require 'Dancer2/Serializer/JSON.pm';
    Dancer2::Serializer::JSON::to_json(@_);
}

sub from_yaml {
    my $app = shift->app;
    require 'Dancer2/Serializer/YAML.pm';
    Dancer2::Serializer::YAML::from_yaml(@_);
}

sub to_yaml {
    my $app = shift->app;
    require 'Dancer2/Serializer/YAML.pm';
    Dancer2::Serializer::YAML::to_yaml(@_);
}

sub from_dumper {
    my $app = shift->app;
    require 'Dancer2/Serializer/Dumper.pm';
    Dancer2::Serializer::Dumper::from_dumper(@_);
}

sub to_dumper {
    my $app = shift->app;
    require 'Dancer2/Serializer/Dumper.pm';
    Dancer2::Serializer::Dumper::to_dumper(@_);
}

sub log { shift->app->log(@_) }

=head1 SEE ALSO

L<http://advent.perldancer.org/2010/18>

=cut

1;

