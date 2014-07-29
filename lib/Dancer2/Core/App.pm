# ABSTRACT: encapsulation of Dancer2 packages
package Dancer2::Core::App;

use Moo;
use Carp            'croak';
use Scalar::Util    'blessed';
use Module::Runtime 'is_module_name';
use File::Spec;

use Dancer2::FileUtils 'path';
use Dancer2::Core;
use Dancer2::Core::Cookie;
use Dancer2::Core::Types;
use Dancer2::Core::Route;
use Dancer2::Core::Hook;

# we have hooks here
with 'Dancer2::Core::Role::Hookable';
with 'Dancer2::Core::Role::ConfigReader';

sub supported_engines { [ qw<logger serializer session template> ] }

has logger_engine => (
    is      => 'ro',
    isa     => Maybe[ConsumerOf['Dancer2::Core::Role::Logger']],
    lazy    => 1,
    builder => '_build_logger_engine',
    writer  => 'set_logger_engine',
);

has session_engine => (
    is      => 'ro',
    isa     => Maybe[ConsumerOf['Dancer2::Core::Role::SessionFactory']],
    lazy    => 1,
    builder => '_build_session_engine',
    writer  => 'set_session_engine',
);

has template_engine => (
    is      => 'ro',
    isa     => Maybe[ConsumerOf['Dancer2::Core::Role::Template']],
    lazy    => 1,
    builder => '_build_template_engine',
    writer  => 'set_template_engine',
);

has serializer_engine => (
    is      => 'ro',
    isa     => Maybe[ConsumerOf['Dancer2::Core::Role::Serializer']],
    lazy    => 1,
    builder => '_build_serializer_engine',
    writer  => 'set_serializer_engine',
);

has '+local_triggers' => (
    default => sub {
        my $self     = shift;
        my $triggers = {
            # general triggers we want to allow, besides engines
            views => sub {
                my $self  = shift;
                my $value = shift;
                $self->template_engine->views($value);
            },

            layout => sub {
                my $self  = shift;
                my $value = shift;
                $self->template_engine->layout($value);
            },

            log => sub {
                my ( $self, $value, $config ) = @_;

                # This will allow to set the log level
                # using: set log => warning
                $self->logger_engine->log_level($value);
            },
        };

        foreach my $engine ( @{ $self->supported_engines } ) {
            $triggers->{$engine} = sub {
                my $self   = shift;
                my $value  = shift;
                my $config = shift;

                ref $value and return $value;

                my $build_method    = "_build_${engine}_engine";
                my $setter_method   = "set_${engine}_engine";
                my $engine_instance = $self->$build_method( $value, $config );

                # set the engine with the new value from the builder
                $self->$setter_method($engine_instance);

                return $engine_instance;
            };
        }

        return $triggers;
    },
);

sub _build_logger_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{logger};

    ref $value and return $value;

    # XXX This is needed for the tests that create an app without
    # a runner.
    defined $value or $value = 'console';

    is_module_name($value)
        or croak "Cannot load logger engine '$value': illegal module name";

    my $engine_options =
        $self->_get_config_for_engine( logger => $value, $config );

    my $logger = Dancer2::Core::Factory->create(
        logger => $value,
        %{$engine_options},
        app_name        => $self->name,
        postponed_hooks => $self->get_postponed_hooks
    );

    exists $config->{log} and $logger->log_level($config->{log});

    return $logger;
}

sub _build_session_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{'session'} || 'simple';

    ref $value and return $value;

    is_module_name($value)
        or croak "Cannot load session engine '$value': illegal module name";

    my $engine_options =
          $self->_get_config_for_engine( session => $value, $config );

    return Dancer2::Core::Factory->create(
        session => $value,
        %{$engine_options},
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _build_template_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{'template'};

    defined $value or return;
    ref $value    and return $value;

    is_module_name($value)
        or croak "Cannot load template engine '$value': illegal module name";

    my $engine_options =
          $self->_get_config_for_engine( template => $value, $config );

    my $engine_attrs = { config => $engine_options };
    $engine_attrs->{layout} ||= $config->{layout};
    $engine_attrs->{views}  ||= $config->{views}
        || path( $self->location, 'views' );

    return Dancer2::Core::Factory->create(
        template => $value,
        %{$engine_attrs},
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _build_serializer_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{serializer};

    defined $value or return;
    ref $value    and return $value;

    my $engine_options =
        $self->_get_config_for_engine( serializer => $value, $config );

    return Dancer2::Core::Factory->create(
        serializer      => $value,
        config          => $engine_options,
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _get_config_for_engine {
    my $self   = shift;
    my $engine = shift;
    my $name   = shift;
    my $config = shift;

    defined $config->{'engines'} && defined $config->{'engines'}{$engine}
        or return {};

    # try both camelized name and regular name
    my $engine_config = {};
    foreach my $engine_name ( $name, Dancer2::Core::camelize($name) ) {
        if ( defined $config->{'engines'}{$engine}{$engine_name} ) {
            $engine_config = $config->{'engines'}{$engine}{$engine_name};
            last;
        }
    }

    return $engine_config;
}

has postponed_hooks => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has plugins => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has route_handlers => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has name => (
    is  => 'ro',
    isa => Str,
);

has request => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Request'],
    writer    => 'set_request',
    clearer   => 'clear_request',
    predicate => 'has_request',
);

has response => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Response'],
    lazy      => 1,
    writer    => 'set_response',
    clearer   => 'clear_response',
    builder   => '_build_response',
    predicate => 'has_response',
);

=attr with_return

Used to cache the coderef from L<Return::MultiLevel> within the dispatcher.

=cut

has with_return => (
    is        => 'ro',
    predicate => 1,
    writer    => 'set_with_return',
    clearer   => 'clear_with_response',
);


has session => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Session'],
    lazy      => 1,
    builder   => '_build_session',
    writer    => 'set_session',
    clearer   => 'clear_session',
    predicate => '_has_session',
);

sub _build_response {
    my $self   = shift;
    my $engine = $self->engine('serializer');

    return Dancer2::Core::Response->new(
        ( serializer => $engine )x!! $engine
    );
}

sub _build_session {
    my $self = shift;
    my $session;

    # Find the session engine
    my $engine = $self->engine('session');

    # find the session cookie if any
    if ( !$self->has_destroyed_session ) {
        my $session_id;
        my $session_cookie = $self->cookie( $engine->cookie_name );
        defined $session_cookie and
            $session_id = $session_cookie->value;

        # if we have a session cookie, try to retrieve the session
        if ( defined $session_id ) {
            eval  { $session = $engine->retrieve( id => $session_id ); 1; }
            or do { $@ and $@ !~ /Unable to retrieve session/
                        and croak "Fail to retrieve session: $@" };
        }
    }

    # create the session if none retrieved
    return $session ||= $engine->create();
}

=method has_session

Returns true if session engine has been defined and if either a session
object has been instantiated or if a session cookie was found and not
subsequently invalidated.

=cut

sub has_session {
    my $self = shift;

    my $engine = $self->engine('session');

    return $self->_has_session
        || ( $self->cookie( $engine->cookie_name )
             && !$self->has_destroyed_session );
}

=attr destroyed_session

We cache a destroyed session here; once this is set we must not attempt to
retrieve the session from the cookie in the request.  If no new session is
created, this is set (with expiration) as a cookie to force the browser to
expire the cookie.

=cut

has destroyed_session => (
    is        => 'ro',
    isa       => InstanceOf ['Dancer2::Core::Session'],
    predicate => 1,
    writer    => 'set_destroyed_session',
    clearer   => 'clear_destroyed_session',
);

=method destroy_session

Destroys the current session and ensures any subsequent session is created
from scratch and not from the request session cookie

=cut

sub destroy_session {
    my $self = shift;

    # Find the session engine
    my $engine = $self->engine('session');

    # Expire session, set the expired cookie and destroy the session
    # Setting the cookie ensures client gets an expired cookie unless
    # a new session is created and supercedes it
    my $session = $self->session;
    $session->expires(-86400);    # yesterday
    $engine->destroy( id => $session->id );

    # Clear session and invalidate session cookie in request
    $self->set_destroyed_session($session);
    $self->clear_session;

    return;
}

sub setup_session {
    my $self = shift;

    for my $type ( @{ $self->supported_engines } ) {
        my $attr   = "${type}_engine";
        my $engine = $self->$attr or next;

        $self->has_session                         ?
            $engine->set_session( $self->session ) :
            $engine->clear_session;
    }
}

has prefix => (
    is        => 'rw',
    isa       => Maybe [Dancer2Prefix],
    predicate => 1,
    coerce    => sub {
        my $prefix = shift;
        defined($prefix) and $prefix eq "/" and return;
        return $prefix;
    },
);

# routes registry, stored by method:
has routes => (
    is      => 'rw',
    isa     => HashRef,
    default => sub {
        {   get     => [],
            head    => [],
            post    => [],
            put     => [],
            del     => [],
            options => [],
        };
    },
);

# add_hook will add the hook to the first "hook candidate" it finds that support
# it. If none, then it will try to add the hook to the current application.
around add_hook => sub {
    my $orig = shift;
    my $self = shift;

    # saving caller information
    my ( $package, $file, $line ) = caller(4);    # deep to 4 : user's app code
    my $add_hook_caller = [ $package, $file, $line ];

    my ($hook)       = @_;
    my $name         = $hook->name;
    my $hook_aliases = $self->all_hook_aliases;

    # look for an alias
    defined $hook_aliases->{$name} and $name = $hook_aliases->{$name};
    $hook->name($name);

    # if that hook belongs to the app, register it now and return
    $self->has_hook($name) and return $self->$orig(@_);

    # at this point the hook name must be formatted like:
    # '$type.$candidate.$name', eg: 'engine.template.before_render' or
    # 'plugin.database.before_dbi_connect'
    my ( $hookable_type, $hookable_name, $hook_name ) = split( /\./, $name );

    ( defined $hookable_name && defined $hook_name )
        or croak "Invalid hook name `$name'";

    grep /^$hookable_type$/, qw(core engine handler plugin)
        or croak "Unknown hook type `$hookable_type'";

    # register the hooks for existing hookable candidates
    foreach my $hookable ( $self->hook_candidates ) {
        $hookable->has_hook($name) and $hookable->add_hook(@_);
    }

    # we register the hook for upcoming objects;
    # that way, each components that can claim the hook will have a chance
    # to register it.

    my $postponed_hooks = $self->postponed_hooks;

    # Hmm, so the hook was not claimed, at this point we'll cache it and
    # register it when the owner is instantiated
    $postponed_hooks->{$hookable_type}{$hookable_name} ||= {};
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name} ||= {};
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name}{hook} = $hook;
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name}{caller} =
      $add_hook_caller;

};

around execute_hook => sub {
    my $orig = shift;
    my $self = shift;

    my ( $hook, @args ) = @_;
    if ( !$self->has_hook($hook) ) {
        foreach my $cand ( $self->hook_candidates ) {
            $cand->has_hook($hook) and return $cand->execute_hook(@_);
        }
    }

    return $self->$orig(@_);
};

sub _build_default_config {
    my $self = shift;

    return {
        content_type   => ( $ENV{DANCER_CONTENT_TYPE} || 'text/html' ),
        charset        => ( $ENV{DANCER_CHARSET}      || '' ),
        logger         => ( $ENV{DANCER_LOGGER}       || 'console' ),
        views          => ( $ENV{DANCER_VIEWS}
                            || path( $self->config_location, 'views' ) ),
        appdir         => $self->location,
        template       => 'Tiny',
        route_handlers => [
            [
                File => {
                    public_dir => $ENV{DANCER_PUBLIC} ||
                                  path( $self->location, 'public' )
                }
            ],
            [
                AutoPage => 1
            ],
        ],
    };
}

sub _init_hooks {
    my $self = shift;

 # Hook to flush the session at the end of the request, this way, we're sure we
 # flush only once per request
    $self->add_hook(
        Dancer2::Core::Hook->new(
            name => 'core.app.after_request',
            code => sub {
                my $response = $self->response;

                # make sure an engine is defined, if not, nothing to do
                my $engine = $self->session_engine;
                defined $engine or return;

                # if a session has been instantiated or we already had a
                # session, first flush the session so cookie-based sessions can
                # update the session ID if needed, then set the session cookie
                # in the response

                if ( $self->has_session ) {
                    my $session = $self->session;
                    $session->is_dirty and $engine->flush( session => $session );
                    $engine->set_cookie_header(
                        response => $response,
                        session  => $session
                    );
                }
                elsif ( $self->has_destroyed_session ) {
                    my $session = $self->destroyed_session;
                    $engine->set_cookie_header(
                        response  => $response,
                        session   => $session,
                        destroyed => 1
                    );
                }
            },
        )
    );
}

sub supported_hooks {
    qw/
      core.app.before_request
      core.app.after_request
      core.app.route_exception
      core.error.before
      core.error.after
      core.error.init
      /;
}

# FIXME not needed anymore, I suppose...
sub api_version {2}

sub register_plugin {
    my $self   = shift;
    my $plugin = shift;

    $self->log( core => "Registered $plugin");

    push @{ $self->plugins }, $plugin;
}

# This method overrides the default one from Role::ConfigReader
sub settings {
    my $self = shift;
    +{ %{ Dancer2->runner->config }, %{ $self->config } };
}

sub cleanup {
    my $self = shift;
    $self->clear_request;
    $self->clear_response;
    $self->clear_session;
    $self->clear_destroyed_session;
}

sub engine {
    my $self = shift;
    my $name = shift;

    grep { $_ eq $name } @{ $self->supported_engines }
        or croak "Engine '$name' is not supported.";

    my $attr_name = "${name}_engine";
    return $self->$attr_name;
}

sub template {
    my $self = shift;

    my $template = $self->template_engine;
    $template->set_settings( $self->config );

    # return content
    return $template->process( $self->request, @_ );
}

sub hook_candidates {
    my $self = shift;

    my @engines;
    for my $e ( @{ $self->supported_engines } ) {
        my $attr   = "${e}_engine";
        my $engine = $self->$attr or next;
        push @engines, $engine;
    }

    my @route_handlers;
    for my $handler ( @{ $self->route_handlers } ) {
        my $handler_code = $handler->{handler};
        blessed $handler_code and $handler_code->can('supported_hooks')
            and push @route_handlers, $handler_code;
    }

    # TODO : get the list of all plugins registered
    my @plugins = @{ $self->plugins };

    ( @route_handlers, @engines, @plugins );
}

sub all_hook_aliases {
    my $self = shift;

    my $aliases = $self->hook_aliases;
    for my $plugin ( @{ $self->plugins } ) {
        $aliases = { %{$aliases}, %{ $plugin->hook_aliases } };
    }

    return $aliases;
}

sub mime_type {
    my $self   = shift;
    my $runner = Dancer2->runner;

    exists $self->config->{default_mime_type}
        ? $runner->mime_type->default( $self->config->{default_mime_type} )
        : $runner->mime_type->reset_default;

    $runner->mime_type;
}

sub log {
    my $self  = shift;
    my $level = shift;

    my $logger = $self->logger_engine
      or croak "No logger defined";

    $logger->$level(@_);
}

sub send_file {
    my $self    = shift;
    my $path    = shift;
    my %options = @_;

    my $env = $self->request->env;

    ( $options{'streaming'} && !$env->{'psgi.streaming'} )
      and croak "Streaming is not supported on this server.";

    ( exists $options{'content_type'} )
      and $self->response->header(
        'Content-Type' => $options{content_type} );

    ( exists $options{filename} )
      and $self->response->header( 'Content-Disposition' =>
          "attachment; filename=\"$options{filename}\"" );

    # if we're given a SCALAR reference, we're going to send the data
    # pretending it's a file (on-the-fly file sending)
    ref $path eq 'SCALAR' and return $$path;

    my $conf = { app => $self };
    my $file_handler = Dancer2::Core::Factory->create(
        Handler => 'File',
        %$conf,
        postponed_hooks => $self->postponed_hooks,
        ( public_dir => File::Spec->rootdir )x!! $options{system_path},
    );

    # List shouldn't be too long, so we use 'grep' instead of 'first'
    if (my ($handler) = grep { $_->{name} eq 'File' } @{$self->route_handlers}) {
        for my $h ( keys %{ $handler->{handler}->hooks } ) {
            my $hooks = $handler->{handler}->hooks->{$h};
            $file_handler->replace_hook( $h, $hooks );
        }
    }

    $self->request->set_path_info($path);
    $file_handler->code( $self->prefix )->( $self ); # slurp file
    $self->has_with_return and $self->with_return->( $self->response );

    # TODO Streaming support
}


sub BUILD {
    my $self = shift;
    $self->init_route_handlers();
    $self->_init_hooks();
}

sub finish {
    my $self = shift;
    $self->register_route_handlers;
    $self->compile_hooks;
}

sub init_route_handlers {
    my $self = shift;

    my $handlers_config = $self->config->{route_handlers};
    for my $handler_data ( @{$handlers_config} ) {
        my ($handler_name, $config) = @{$handler_data};
        ref $config or $config = {};
        $config->{app} = $self;

        my $handler = Dancer2::Core::Factory->create(
            Handler => $handler_name,
            %$config,
            postponed_hooks => $self->postponed_hooks,
        );

        push @{ $self->route_handlers }, {
            name    => $handler_name,
            handler => $handler,
        };
    }
}

sub register_route_handlers {
    my $self = shift;
    for my $handler ( @{$self->route_handlers} ) {
        my $handler_code = $handler->{handler};
        $handler_code->register($self);
    }
}

sub compile_hooks {
    my ($self) = @_;

    for my $position ( $self->supported_hooks ) {
        my $compiled_hooks = [];
        for my $hook ( @{ $self->hooks->{$position} } ) {
            my $compiled = sub {
                # don't run the filter if halt has been used
                $self->has_response && $self->response->is_halted
                    and return;

                eval  { $hook->(@_); 1; }
                or do { croak "Exception caught in '$position' filter: $@" };
            };

            push @{$compiled_hooks}, $compiled;
        }
        $self->replace_hook( $position, $compiled_hooks );
    }
}

sub lexical_prefix {
    my $self   = shift;
    my $prefix = shift;
    my $cb     = shift;

    $prefix eq '/' and undef $prefix;

    # save the app prefix
    my $app_prefix = $self->prefix;

    # alter the prefix for the callback
    my $new_prefix =
        ( defined $app_prefix ? $app_prefix : '' )
      . ( defined $prefix     ? $prefix     : '' );

    # if the new prefix is empty, it's a meaningless prefix, just ignore it
    length $new_prefix and $self->prefix($new_prefix);

    eval { $cb->() };
    my $e = $@;

    # restore app prefix
    $self->prefix($app_prefix);

    $e and croak "Unable to run the callback for prefix '$prefix': $e";
}

sub add_route {
    my $self        = shift;
    my %route_attrs = @_;

    my $route =
      Dancer2::Core::Route->new( %route_attrs, prefix => $self->prefix );

    my $method = $route->method;

    push @{ $self->routes->{$method} }, $route;
}

sub route_exists {
    my $self  = shift;
    my $route = shift;

    my $routes = $self->routes->{ $route->method };

    foreach my $existing_route (@$routes) {
        $existing_route->spec_route eq $route->spec_route
            and return 1;
    }
    return 0;
}

sub routes_regexps_for {
    my $self   = shift;
    my $method = shift;

    return [ map { $_->regexp } @{ $self->routes->{$method} } ];
}

sub cookie {
    my $self = shift;

    @_ == 1 and return $self->request->cookies->{ $_[0] };

    # writer
    my ( $name, $value, %options ) = @_;
    my $c =
      Dancer2::Core::Cookie->new( name => $name, value => $value, %options );
    $self->response->push_header( 'Set-Cookie' => $c->to_header );
}

=method redirect($destination, $status)

Sets a redirect in the response object.  If $destination is not an absolute URI, then it will
be made into an absolute URI, relative to the URI in the request.

=cut

sub redirect {
    my $self        = shift;
    my $destination = shift;
    my $status      = shift;

    # RFC 2616 requires an absolute URI with a scheme,
    # turn the URI into that if it needs it

    # Scheme grammar as defined in RFC 2396
    #  scheme = alpha *( alpha | digit | "+" | "-" | "." )
    my $scheme_re = qr{ [a-z][a-z0-9\+\-\.]* }ix;
    if ( $destination !~ m{^ $scheme_re : }x ) {
        $destination = $self->request->uri_for( $destination, {}, 1 );
    }

    $self->response->redirect( $destination, $status );

    # Short circuit any remaining before hook / route code
    # ('pass' and after hooks are still processed)
    $self->has_with_return
        and $self->with_return->($self->response);
}

=method halt

Flag the response object as 'halted'.

If called during request dispatch, immediatly returns the response
to the dispatcher and after hooks will not be run.

=cut

sub halt {
   my $self = shift;
   $self->response->halt;

   # Short citcuit any remaining hook/route code
   $self->has_with_return
       and $self->with_return->($self->response);
}

=method pass

Flag the response object as 'passed'.

If called during request dispatch, immediatly returns the response
to the dispatcher.

=cut

sub pass {
   my $self = shift;
   $self->response->pass;

   # Short citcuit any remaining hook/route code
   $self->has_with_return
       and $self->with_return->($self->response);
}

=method forward

Create a new request which is a clone of the current one, apart
from the path location, which points instead to the new location.
This is used internally to chain requests using the forward keyword.

Note that the new location should be a hash reference. Only one key is
required, the C<to_url>, that should point to the URL that forward
will use. Optional values are the key C<params> to a hash of
parameters to be added to the current request parameters, and the key
C<options> that points to a hash of options about the redirect (for
instance, C<method> pointing to a new request method).

=cut

sub forward {
    my $self    = shift;
    my $url     = shift;
    my $params  = shift;
    my $options = shift;

    my $new_request = $self->make_forward_to( $url, $params, $options );

    $self->has_with_return
        and $self->with_return->($new_request);

    # nothing else will run after this
}

# Create a new request which is a clone of the current one, apart
# from the path location, which points instead to the new location
# TODO this could be written in a more clean manner with a clone mechanism
sub make_forward_to {
    my $self    = shift;
    my $url     = shift;
    my $params  = shift;
    my $options = shift;

    my $request = $self->request;

    # we clone the env to make sure we don't alter the existing one in $self
    my $env = { %{ $request->env } };

    $env->{PATH_INFO} = $url;

    my $new_request = Dancer2::Core::Request->new( env => $env, body_is_parsed => 1 );
    my $new_params = _merge_params( scalar( $request->params ), $params || {} );

    exists $options->{method} and
        $new_request->method( $options->{method} );

    # Copy params (these are already decoded)
    $new_request->{_params}       = $new_params;
    $new_request->{_body_params}  = $request->{_body_params};
    $new_request->{_query_params} = $request->{_query_params};
    $new_request->{_route_params} = $request->{_route_params};
    $new_request->{body}          = $request->body;
    $new_request->{headers}       = $request->headers;

    # If a session object was created during processing of the original request
    # i.e. a session object exists but no cookie existed
    # add a cookie so the dispatcher can assign the session to the appropriate app
    my $engine = $self->engine('session');
    $engine && $self->_has_session or return $new_request;
    my $name = $engine->cookie_name;
    exists $new_request->cookies->{$name} and return $new_request;
    $new_request->cookies->{$name} =
        Dancer2::Core::Cookie->new( name => $name, value => $self->session->id );
    return $new_request;
}

sub _merge_params {
    my $params = shift;
    my $to_add = shift;

    for my $key ( keys %$to_add ) {
        $params->{$key} = $to_add->{$key};
    }
    return $params;
}

sub app { shift }

1;

__END__

=head1 DESCRIPTION

Everything a package that uses Dancer2 does is encapsulated into a
C<Dancer2::Core::App> instance. This class defines all that can be done in such
objects.

Mainly, it will contain all the route handlers, the configuration settings and
the hooks that are defined in the calling package.

Note that with Dancer2, everything that is done within a package is scoped to
that package, thanks to that encapsulation.

=attr plugins

=attr runner_config

=attr default_config

=method register_plugin

=head2 lexical_prefix

Allow for setting a lexical prefix

    $app->lexical_prefix('/blog', sub {
        ...
    });

All the route defined within the callback will have a prefix appended to the
current one.

=head2 add_route

Register a new route handler.

    $app->add_route(
        method  => 'get',
        regexp  => '/somewhere',
        code    => sub { ... },
        options => $conditions,
    );

=head2 route_exists

Check if a route already exists.

    my $route = Dancer2::Core::Route->new(...);
    if ($app->route_exists($route)) {
        ...
    }

=head2 routes_regexps_for

Sugar for getting the ordered list of all registered route regexps by method.

    my $regexps = $app->routes_regexps_for( 'get' );

Returns an ArrayRef with the results.

=head2 app

Returns itself. This is simply available as a shim to help transition from
a previous version in which hooks were sent a context object (originally
C<Dancer2::Core::Context>) which has since been removed.

    # before
    hook before => sub {
        my $ctx = shift;
        my $app = $ctx->app;
    };

    # after
    hook before => sub {
        my $app = shift;
    };

This meant that C<< $app->app >> would fail, so this method has been provided
to make it work.

    # now
    hook before => sub {
        my $WannaBeCtx = shift;
        my $app        = $WannaBeContext->app; # works
    };

