# ABSTRACT: encapsulation of Dancer2 packages
package Dancer2::Core::App;

use Moo;
use Carp               qw<croak carp>;
use Scalar::Util       'blessed';
use Module::Runtime    'is_module_name';
use Safe::Isa;
use Sub::Quote;
use File::Spec;
use Module::Runtime    'use_module';
use List::Util         ();
use Ref::Util          qw< is_ref is_globref is_scalarref >;

use Plack::App::File;
use Plack::Middleware::FixMissingBodyInRedirect;
use Plack::Middleware::Head;
use Plack::Middleware::Conditional;
use Plack::Middleware::ConditionalGET;

use Dancer2::FileUtils 'path';
use Dancer2::Core;
use Dancer2::Core::Cookie;
use Dancer2::Core::Error;
use Dancer2::Core::Types;
use Dancer2::Core::Route;
use Dancer2::Core::Hook;
use Dancer2::Core::Request;
use Dancer2::Core::Factory;

use Dancer2::Handler::File;

our $EVAL_SHIM; $EVAL_SHIM ||= sub {
    my $code = shift;
    $code->(@_);
};


# we have hooks here
with qw<
    Dancer2::Core::Role::Hookable
    Dancer2::Core::Role::ConfigReader
>;

sub supported_engines { [ qw<logger serializer session template> ] }

sub with_plugins {
    my ( $self, @plugins ) = @_;
    return map $self->_with_plugin($_), @plugins;

}

sub _with_plugin {
    my( $self, $plugin ) = @_;

    if ( is_ref($plugin) ) {
        # passing the plugin as an already-created object

        # already loaded?
        if( my ( $already ) = grep { ref($plugin) eq ref $_; } @{ $self->plugins } ) {
                die "trying to load two different objects for plugin ". ref $plugin
                    if refaddr($plugin) != refaddr $already ;

        }
        else {
            push @{ $self->plugins }, $plugin;
        }

        return $plugin;
    }

    # short plugin names get Dancer2::Plugin:: prefix
    # plugin names starting with a '+' are full package names
    if ( $plugin !~ s/^\+// ) {
        $plugin =~ s/^(?!Dancer2::Plugin::)/Dancer2::Plugin::/;
    }

    # check if it's already there
    if( my ( $already ) = grep { $plugin eq ref $_ } @{ $self->plugins } ) {
        return $already;
    }

    push @{ $self->plugins },
         $plugin = use_module($plugin)->new( app => $self );

    return $plugin;
}

sub with_plugin {
    my( $self, $plugin ) = @_;

    croak "expected a single argument"
        unless @_ == 2;

    ( $self->with_plugins($plugin) )[0];
}

has _factory => (
    is      => 'ro',
    isa     => InstanceOf['Dancer2::Core::Factory'],
    lazy    => 1,
    default => sub { Dancer2::Core::Factory->new },
);

has logger_engine => (
    is        => 'ro',
    isa       => ConsumerOf['Dancer2::Core::Role::Logger'],
    lazy      => 1,
    builder   => '_build_logger_engine',
    writer    => 'set_logger_engine',
);

has session_engine => (
    is      => 'ro',
    isa     => ConsumerOf['Dancer2::Core::Role::SessionFactory'],
    lazy    => 1,
    builder => '_build_session_engine',
    writer  => 'set_session_engine',
);

has template_engine => (
    is      => 'ro',
    isa     => ConsumerOf['Dancer2::Core::Role::Template'],
    lazy    => 1,
    builder => '_build_template_engine',
    writer  => 'set_template_engine',
);

has serializer_engine => (
    is      => 'ro',
    isa     => ConsumerOf['Dancer2::Core::Role::Serializer'],
    lazy    => 1,
    builder => '_build_serializer_engine',
    writer  => 'set_serializer_engine',
    predicate => 'has_serializer_engine',
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

            layout_dir => sub {
                my $self  = shift;
                my $value = shift;
                $self->template_engine->layout_dir($value);
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

                is_ref($value) and return $value;

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

    is_ref($value) and return $value;

    # XXX This is needed for the tests that create an app without
    # a runner.
    defined $value or $value = 'console';

    is_module_name($value)
        or croak "Cannot load logger engine '$value': illegal module name";

    my $engine_options =
        $self->_get_config_for_engine( logger => $value, $config );

    my $logger = $self->_factory->create(
        logger          => $value,
        %{$engine_options},
        location        => $self->config_location,
        environment     => $self->environment,
        app_name        => $self->name,
        postponed_hooks => $self->postponed_hooks
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

    is_ref($value) and return $value;

    is_module_name($value)
        or croak "Cannot load session engine '$value': illegal module name";

    my $engine_options =
          $self->_get_config_for_engine( session => $value, $config );

    Scalar::Util::weaken( my $weak_self = $self );

    # Note that engine options will replace the default session_dir (if provided).
    return $self->_factory->create(
        session         => $value,
        session_dir     => path( $self->config->{appdir}, 'sessions' ),
        %{$engine_options},
        postponed_hooks => $self->postponed_hooks,

        log_cb => sub { $weak_self->log(@_) },
    );
}

sub _build_template_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{'template'};

    defined $value or return;
    is_ref($value) and return $value;

    is_module_name($value)
        or croak "Cannot load template engine '$value': illegal module name";

    my $engine_options =
          $self->_get_config_for_engine( template => $value, $config );

    my $engine_attrs = {
        config => $engine_options,
        layout => $config->{layout},
        layout_dir => ( $config->{layout_dir} || 'layouts' ),
        views => $config->{views},
    };

    Scalar::Util::weaken( my $weak_self = $self );

    return $self->_factory->create(
        template        => $value,
        %{$engine_attrs},
        postponed_hooks => $self->postponed_hooks,

        log_cb => sub { $weak_self->log(@_) },
    );
}

sub _build_serializer_engine {
    my $self   = shift;
    my $value  = shift;
    my $config = shift;

    defined $config or $config = $self->config;
    defined $value  or $value  = $config->{serializer};

    defined $value or return;
    is_ref($value) and return $value;

    my $engine_options =
        $self->_get_config_for_engine( serializer => $value, $config );

    Scalar::Util::weaken( my $weak_self = $self );

    return $self->_factory->create(
        serializer      => $value,
        config          => $engine_options,
        postponed_hooks => $self->postponed_hooks,

        log_cb => sub { $weak_self->log(@_) },
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

# TODO I'd be happier with a HashRef, really
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
    is      => 'ro',
    isa     => Str,
    default => sub { (caller(1))[0] },
);

has request => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Request'],
    writer    => '_set_request',
    clearer   => 'clear_request',
    predicate => 'has_request',
);

sub set_request {
    my ($self, $request, $defined_engines) = @_;
    # typically this is passed in as an optimization within the
    # dispatch loop but may be called elsewhere
    $defined_engines ||= $self->defined_engines;
    # populate request in app and all engines
    $self->_set_request($request);
    Scalar::Util::weaken( my $weak_request = $request );
    $_->set_request( $weak_request ) for @{$defined_engines};
}

has response => (
    is        => 'ro',
    isa       => InstanceOf['Dancer2::Core::Response'],
    lazy      => 1,
    writer    => 'set_response',
    clearer   => 'clear_response',
    builder   => '_build_response',
    predicate => 'has_response',
);

has with_return => (
    is        => 'ro',
    predicate => 1,
    writer    => 'set_with_return',
    clearer   => 'clear_with_return',
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

around _build_config => sub {
    my ( $orig, $self ) = @_;
    my $config          = $self->$orig;

    if ( $config && $config->{'engines'} ) {
        $self->_validate_engine($_) for keys %{ $config->{'engines'} };
    }

    return $config;
};

sub _build_response {
    my $self = shift;
    return Dancer2::Core::Response->new(
        server_tokens => !$self->config->{'no_server_tokens'},
        $self->has_serializer_engine
            ? ( serializer => $self->serializer_engine )
            : (),
    );
}

sub _build_session {
    my $self = shift;
    my $session;

    # Find the session engine
    my $engine = $self->session_engine;

    # find the session cookie if any
    if ( !$self->has_destroyed_session ) {
        my $session_id;
        my $session_cookie = $self->cookie( $engine->cookie_name );
        defined $session_cookie and
            $session_id = $session_cookie->value;

        # if we have a session cookie, try to retrieve the session
        if ( defined $session_id ) {
            eval  {
                $EVAL_SHIM->(sub {
                    $session = $engine->retrieve( id => $session_id );
                });
                1;
            }
            or do {
                my $err = $@ || "Zombie Error";
                if ( $err !~ /Unable to retrieve session/ ) {
                    croak "Failed to retrieve session: $err"
                } else {
                    # XXX we throw away the error entirely? Why?
                }
            };
        }
    }

    # create the session if none retrieved
    return $session ||= $engine->create();
}

sub has_session {
    my $self = shift;

    my $engine = $self->session_engine;

    return $self->_has_session
        || ( $self->cookie( $engine->cookie_name )
             && !$self->has_destroyed_session );
}

has destroyed_session => (
    is        => 'ro',
    isa       => InstanceOf ['Dancer2::Core::Session'],
    predicate => 1,
    writer    => 'set_destroyed_session',
    clearer   => 'clear_destroyed_session',
);

has 'prep_apps' => (
    'is'      => 'ro',
    'isa'     => ArrayRef,
    'default' => sub { [] },
);

sub find_plugin {
    my ( $self, $name ) = @_;
    my $plugin = List::Util::first { ref($_) eq $name } @{ $self->plugins };
    $plugin or return;
    return $plugin;
}

sub destroy_session {
    my $self = shift;

    # Find the session engine
    my $engine = $self->session_engine;

    # Expire session, set the expired cookie and destroy the session
    # Setting the cookie ensures client gets an expired cookie unless
    # a new session is created and supercedes it
    my $session = $self->session;
    $session->expires(-86400);    # yesterday
    $engine->destroy( id => $session->id );

    # Invalidate session cookie in request
    # and clear session in app and engines
    $self->set_destroyed_session($session);
    $self->clear_session;
    $_->clear_session for @{ $self->defined_engines };

    return;
}

sub setup_session {
    my $self = shift;

    for my $engine ( @{ $self->defined_engines } ) {
        $self->has_session                         ?
            $engine->set_session( $self->session ) :
            $engine->clear_session;
    }
}

sub change_session_id {
    my $self = shift;

    my $session = $self->session;

    # Find the session engine
    my $engine = $self->session_engine;

    if ($engine->can('_change_id')) {

        # session engine can change session ID
        $engine->change_id( session => $session );
    }
    else {

        # Method order is important in here...
        #
        # On session build if there is no destroyed session then the session
        # builder tries to recreate the session using the existing session
        # cookie. We really don't want to do that in this case so it is
        # important to create the new session before the
        # clear_destroyed_session method is called.
        #
        # This sucks.
        #
        # Sawyer suggested:
        #
        # What if you take the session cookie logic out of that attribute into
        # another attribute and clear that attribute?
        # That would force the session rebuilt to rebuilt the attribute and
        # get a different cookie value, no?
        #
        # TODO: think about this some more.

        # grab data, destroy session and store data again
        my %data = %{$session->data};

        # destroy existing session
        $self->destroy_session;

        # get new session
        $session = $self->session;

        # write data from old session into new
        # Some engines add session id to data so skip id.
        while (my ($key, $value) = each %data ) {
            $session->write($key => $value) unless $key eq 'id';
        }

        # clear out destroyed session - no longer relevant
        $self->clear_destroyed_session;
    }

    return $session->id;
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

    local $Dancer2::Core::Route::REQUEST  = $self->request;
    local $Dancer2::Core::Route::RESPONSE = $self->response;

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

    my $public = $ENV{DANCER_PUBLIC} || path( $self->location, 'public' );
    return {
        content_type   => ( $ENV{DANCER_CONTENT_TYPE} || 'text/html' ),
        charset        => ( $ENV{DANCER_CHARSET}      || '' ),
        logger         => ( $ENV{DANCER_LOGGER}       || 'console' ),
        views          => ( $ENV{DANCER_VIEWS}
                            || path( $self->location, 'views' ) ),
        environment    => $self->environment,
        appdir         => $self->location,
        public_dir     => $public,
        template       => 'Tiny',
        route_handlers => [
            [
                AutoPage => 1
            ],
        ],
    };
}

sub _init_hooks {
    my $self = shift;

    # Hook to flush the session at the end of the request,
    # this way, we're sure we flush only once per request
    #
    # Note: we create a weakened copy $self
    # before closing over the weakened copy
    # to avoid circular memory refs.
    Scalar::Util::weaken(my $app = $self);

    $self->add_hook(
        Dancer2::Core::Hook->new(
            name => 'core.app.after_request',
            code => sub {
                my $response = $Dancer2::Core::Route::RESPONSE;

                # make sure an engine is defined, if not, nothing to do
                my $engine = $app->session_engine;
                defined $engine or return;

                # if a session has been instantiated or we already had a
                # session, first flush the session so cookie-based sessions can
                # update the session ID if needed, then set the session cookie
                # in the response
                #
                # if there is NO session object but the request has a cookie with
                # a session key, create a dummy session with the same ID (without
                # actually retrieving and flushing immediately) and generate the
                # cookie header from the dummy session. Lazy Sessions FTW!

                if ( $app->has_session ) {
                    my $session;
                    if ( $app->_has_session ) { # Session object exists
                        $session = $app->session;
                        $session->is_dirty and $engine->flush( session => $session );
                    }
                    else { # Cookie header exists. Create a dummy session object
                        my $cookie = $app->cookie( $engine->cookie_name );
                        my $session_id = $cookie->value;
                        $session = Dancer2::Core::Session->new( id => $session_id );
                    }
                    $engine->set_cookie_header(
                        response => $response,
                        session  => $session
                    );
                }
                elsif ( $app->has_destroyed_session ) {
                    my $session = $app->destroyed_session;
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
      core.app.before_file_render
      core.app.after_file_render
      core.error.before
      core.error.after
      core.error.init
      /;
}

sub hook_aliases {
    my $self = shift;
    $self->{'hook_aliases'} ||= {
        before                 => 'core.app.before_request',
        before_request         => 'core.app.before_request',
        after                  => 'core.app.after_request',
        after_request          => 'core.app.after_request',
        init_error             => 'core.error.init',
        before_error           => 'core.error.before',
        after_error            => 'core.error.after',
        on_route_exception     => 'core.app.route_exception',

        before_file_render         => 'core.app.before_file_render',
        after_file_render          => 'core.app.after_file_render',
        before_handler_file_render => 'handler.file.before_render',
        after_handler_file_render  => 'handler.file.after_render',


        # compatibility from Dancer1
        before_error_render    => 'core.error.before',
        after_error_render     => 'core.error.after',
        before_error_init      => 'core.error.init',

        # TODO: call $engine->hook_aliases as needed
        # But.. currently there are use cases where hook_aliases
        # are needed before the engines are intiialized :(
        before_template_render => 'engine.template.before_render',
        after_template_render  => 'engine.template.after_render',
        before_layout_render   => 'engine.template.before_layout_render',
        after_layout_render    => 'engine.template.after_layout_render',
        before_serializer      => 'engine.serializer.before',
        after_serializer       => 'engine.serializer.after',
    };
}

sub defined_engines {
    my $self = shift;
    return [
        $self->template_engine,
        $self->session_engine,
        $self->logger_engine,
        $self->has_serializer_engine
            ? $self->serializer_engine
            : (),
    ];
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
    +{ %{ Dancer2::runner()->config }, %{ $self->config } };
}

sub cleanup {
    my $self = shift;
    $self->clear_request;
    $self->clear_response;
    $self->clear_session;
    $self->clear_destroyed_session;
    # Clear engine attributes
    for my $engine ( @{ $self->defined_engines } ) {
        $engine->clear_session;
        $engine->clear_request;
    }
}

sub _validate_engine {
    my $self = shift;
    my $name = shift;

    grep +( $_ eq $name ), @{ $self->supported_engines }
        or croak "Engine '$name' is not supported.";
}

sub engine {
    my $self = shift;
    my $name = shift;

    $self->_validate_engine($name);

    my $attr_name = "${name}_engine";
    return $self->$attr_name;
}

sub template {
    my $self = shift;

    my $template = $self->template_engine;
    $template->set_settings( $self->config );

    # A session will not exist if there is no request (global keyword)
    #
    # A session may exist but the route code may not have instantiated
    # the session object (sessions are lazy). If this is the case, do
    # that now, so the templates have the session data for rendering.
    $self->has_request && $self->has_session && ! $template->has_session
        and $self->setup_session;

    # return content
    return $template->process( @_ );
}

sub hook_candidates {
    my $self = shift;

    my @engines = @{ $self->defined_engines };

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
    for my $plugin ( grep { $_->can('hook_aliases') } @{ $self->plugins } ) {
        $aliases = { %{$aliases}, %{ $plugin->hook_aliases } };
    }

    return $aliases;
}

sub mime_type {
    my $self   = shift;
    my $runner = Dancer2::runner();

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

sub send_as {
    my $self = shift;
    my ( $type, $data, $options ) = @_;
    $options ||= {};

    $type or croak "Can not send_as using an undefined type";

    if ( lc($type) eq 'html' || lc($type) eq 'plain' ) {
        if ( $type ne lc $type ) {
            local $Carp::CarpLevel = 2;
            carp sprintf( "Please use %s as the type for 'send_as', not %s", lc($type), $type );
        }

        $options->{charset} = $self->config->{charset} || 'UTF-8';
        my $content = Encode::encode( $options->{charset}, $data );
        $options->{content_type} ||= join '/', 'text', lc $type;
        $self->send_file( \$content, %$options );     # returns from sub
    }

    # Try and load the serializer class
    my $serializer_class = "Dancer2::Serializer::$type";
    eval {
        $EVAL_SHIM->(sub {
            require_module( $serializer_class );
        });
        1;
    } or do {
        my $err = $@ || "Zombie Error";
        croak "Unable to load serializer class for $type: $err";
    };

    # load any serializer engine config
    my $engine_options =
        $self->_get_config_for_engine( serializer => $type, $self->config ) || {};
    my $serializer = $serializer_class->new( config => $engine_options );
    my $content = $serializer->serialize( $data );
    $options->{content_type} ||= $serializer->content_type;
    $self->send_file( \$content, %$options );
}

sub send_error {
    my $self = shift;
    my ( $message, $status ) = @_;

    my $err = Dancer2::Core::Error->new(
          message    => $message,
          app        => $self,
        ( status     => $status     )x!! $status,

        $self->has_serializer_engine
            ? ( serializer => $self->serializer_engine )
            : (),
    )->throw;

    # Immediately return to dispatch if with_return coderef exists
    $self->has_with_return && $self->with_return->($err);
    return $err;
}

sub send_file {
    my $self    = shift;
    my $thing   = shift;
    my %options = @_;

    my ($content_type, $charset, $file_path);

    # are we're given a filehandle? (based on what Plack::Middleware::Lint accepts)
    my $is_filehandle = Plack::Util::is_real_fh($thing)
      || ( is_globref($thing) && *{$thing}{IO} && *{$thing}{IO}->can('getline') )
      || ( Scalar::Util::blessed($thing) && $thing->can('getline') );
    my ($fh) = ($thing)x!! $is_filehandle;

    # if we're given an IO::Scalar object, DTRT (take the scalar ref from it)
    if (Scalar::Util::blessed($thing) && $thing->isa('IO::Scalar')) {
        $thing = $thing->sref;
    }

    # if we're given a SCALAR reference, build a filehandle to it
    if ( is_scalarref($thing) ) {
        ## no critic qw(InputOutput::RequireCheckedOpen)
        open $fh, "<", $thing;
    }

    # If we haven't got a filehandle, create one to the requested content
    if (! $fh) {
        my $path = $thing;
        # remove prefix from given path (if not a filehandle)
        my $prefix = $self->prefix;
        if ( $prefix && $prefix ne '/' ) {
            $path =~ s/^\Q$prefix\E//;
        }
        # static file dir - either system root or public_dir
        my $dir = $options{system_path}
            ? File::Spec->rootdir
            : $ENV{DANCER_PUBLIC}
                || $self->config->{public_dir}
                || path( $self->location, 'public' );

        $file_path = Dancer2::Handler::File->merge_paths( $path, $dir );
        my $err_response = sub {
            my $status = shift;
            $self->response->status($status);
            $self->response->header( 'Content-Type', 'text/plain' );
            $self->response->content( Dancer2::Core::HTTP->status_message($status) );
            $self->with_return->( $self->response );
        };
        $err_response->(403) if !defined $file_path;
        $err_response->(404) if !-f $file_path;
        $err_response->(403) if !-r $file_path;

        # Read file content as bytes
        $fh = Dancer2::FileUtils::open_file( "<", $file_path );
        binmode $fh;
        $content_type = Dancer2::runner()->mime_type->for_file($file_path) || 'text/plain';
        if ( $content_type =~ m!^text/! ) {
            $charset = $self->config->{charset} || "utf-8";
        }
    }

    # Now we are sure we can render the file...
    $self->execute_hook( 'core.app.before_file_render', $file_path );

    # response content type and charset
    ( exists $options{'content_type'} ) and $content_type = $options{'content_type'};
    ( exists $options{'charset'} ) and $charset = $options{'charset'};
    $content_type .= "; charset=$charset" if $content_type and $charset;
    ( defined $content_type )
      and $self->response->header('Content-Type' => $content_type );

    # content disposition
    ( exists $options{filename} )
      and $self->response->header( 'Content-Disposition' =>
          ($options{content_disposition} || "attachment") . "; filename=\"$options{filename}\"" );

    # use a delayed response unless server does not support streaming
    my $use_streaming = exists $options{streaming} ? $options{streaming} : 1;
    my $response;
    my $env = $self->request->env;
    if ( $env->{'psgi.streaming'} && $use_streaming ) {
        my $cb = sub {
            my $responder = $Dancer2::Core::Route::RESPONDER;
            my $res = $Dancer2::Core::Route::RESPONSE;
            return $responder->(
                [ $res->status, $res->headers_to_array, $fh ]
            );
        };

        Scalar::Util::weaken( my $weak_self = $self );

        $response = Dancer2::Core::Response::Delayed->new(
            error_cb => sub { $weak_self->logger_engine->log( warning => @_ ) },
            cb       => $cb,
            request  => $Dancer2::Core::Route::REQUEST,
            response => $Dancer2::Core::Route::RESPONSE,
        );
    }
    else {
        $response = $self->response;
        # direct assignment to hash element, avoids around modifier
        # trying to serialise this this content.
        $response->{content} = Dancer2::FileUtils::read_glob_content($fh);
        $response->is_encoded(1);    # bytes are already encoded
    }

    $self->execute_hook( 'core.app.after_file_render', $response );
    $self->with_return->( $response );
}

sub BUILD {
    my $self = shift;
    $self->init_route_handlers();
    $self->_init_hooks();
}

sub finish {
    my $self = shift;

    # normalize some values that require calculations
    defined $self->config->{'static_handler'}
        or $self->config->{'static_handler'} = -d $self->config->{'public_dir'};

    $self->register_route_handlers;
    $self->compile_hooks;

    @{$self->plugins}
        && $self->plugins->[0]->can('_add_postponed_plugin_hooks')
        && $self->plugins->[0]->_add_postponed_plugin_hooks(
            $self->postponed_hooks
        );

    foreach my $prep_cb ( @{ $self->prep_apps } ) {
        $prep_cb->($self);
    }
}

sub init_route_handlers {
    my $self = shift;

    my $handlers_config = $self->config->{route_handlers};
    for my $handler_data ( @{$handlers_config} ) {
        my ($handler_name, $config) = @{$handler_data};
        $config = {} if !is_ref($config);

        my $handler = $self->_factory->create(
            Handler         => $handler_name,
            app             => $self,
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
            Scalar::Util::weaken( my $app = $self );
            my $compiled = sub {
                # don't run the filter if halt has been used
                $Dancer2::Core::Route::RESPONSE &&
                $Dancer2::Core::Route::RESPONSE->is_halted
                    and return;

                eval  { $EVAL_SHIM->($hook,@_); 1; }
                or do {
                    my $err = $@ || "Zombie Error";
                    $app->cleanup;
                    $app->log('error', "Exception caught in '$position' filter: $err");
                    croak "Exception caught in '$position' filter: $err";
                };
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

    my $err;
    my $ok= eval { $EVAL_SHIM->($cb); 1 }
            or do { $err = $@ || "Zombie Error"; };

    # restore app prefix
    $self->prefix($app_prefix);

    $ok or croak "Unable to run the callback for prefix '$prefix': $err";
}

sub add_route {
    my $self        = shift;
    my %route_attrs = @_;

    my $route = Dancer2::Core::Route->new(
        type_library => $self->config->{type_library},
        %route_attrs,
        prefix => $self->prefix,
    );

    my $method = $route->method;

    push @{ $self->routes->{$method} }, $route;

    return $route;
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

    return [ map $_->regexp, @{ $self->routes->{$method} } ];
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

sub redirect {
    my $self        = shift;
    my $destination = shift;
    my $status      = shift;

    $self->response->redirect( $destination, $status );

    # Short circuit any remaining before hook / route code
    # ('pass' and after hooks are still processed)
    $self->has_with_return
        and $self->with_return->($self->response);
}

sub halt {
   my $self = shift;
   $self->response->halt( @_ );

   # Short citcuit any remaining hook/route code
   $self->has_with_return
       and $self->with_return->($self->response);
}

sub pass {
   my $self = shift;
   $self->response->pass;

   # Short citcuit any remaining hook/route code
   $self->has_with_return
       and $self->with_return->($self->response);
}

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
sub make_forward_to {
    my $self    = shift;
    my $url     = shift;
    my $params  = shift;
    my $options = shift;

    my $overrides = { PATH_INFO => $url };
    exists $options->{method} and
        $overrides->{REQUEST_METHOD} = $options->{method};

    # "clone" the existing request
    my $new_request = $self->request->_shallow_clone( $params, $overrides );

    # If a session object was created during processing of the original request
    # i.e. a session object exists but no cookie existed
    # add a cookie so the dispatcher can assign the session to the appropriate app
    my $engine = $self->session_engine;
    $engine && $self->_has_session or return $new_request;
    my $name = $engine->cookie_name;
    exists $new_request->cookies->{$name} and return $new_request;
    $new_request->cookies->{$name} =
        Dancer2::Core::Cookie->new( name => $name, value => $self->session->id );

    return $new_request;
}

sub app { shift }

# DISPATCHER
sub to_app {
    my $self = shift;

    # build engines
    {
        for ( qw<logger session template> ) {
            my $attr = "${_}_engine";
            $self->$attr;
        }

        # the serializer engine does not have a default
        # and is the only engine that can actually not have a value
        if ( $self->config->{'serializer'} ) {
            $self->serializer_engine;
        }
    }

    $self->finish;

    my $psgi = sub {
        my $env = shift;

        # pre-request sanity check
        my $method = uc $env->{'REQUEST_METHOD'};
        $Dancer2::Core::Types::supported_http_methods{$method}
            or return [
                405,
                [ 'Content-Type' => 'text/plain' ],
                [ "Method Not Allowed\n\n$method is not supported." ]
            ];

        my $response;
        eval {
            $EVAL_SHIM->(sub{ $response = $self->dispatch($env)->to_psgi });
            1;
        } or do {
            my $err = $@ || "Zombie Error";
            return [
                500,
                [ 'Content-Type' => 'text/plain' ],
                [ "Internal Server Error\n\n$err"  ],
            ];
        };

        return $response;
    };

    # Only add static content handler if required
    if ( $self->config->{'static_handler'} ) {
        # Use App::File to "serve" the static content
        my $static_app = Plack::App::File->new(
            root         => $self->config->{public_dir},
            content_type => sub { $self->mime_type->for_name(shift) },
        )->to_app;
        # Conditionally use the static handler wrapped with ConditionalGET
        # when the file exists. Otherwise the request passes into our app.
        $psgi = Plack::Middleware::Conditional->wrap(
            $psgi,
            condition => sub { -f path( $self->config->{public_dir}, shift->{PATH_INFO} ) },
            builder   => sub { Plack::Middleware::ConditionalGET->wrap( $static_app ) },
        );
    }

    # Wrap with common middleware
    if ( ! $self->config->{'no_default_middleware'} ) {
        # FixMissingBodyInRedirect
        $psgi = Plack::Middleware::FixMissingBodyInRedirect->wrap( $psgi );
        # Apply Head. After static so a HEAD request on static content DWIM.
        $psgi = Plack::Middleware::Head->wrap( $psgi );
    }

    return $psgi;
}

sub dispatch {
    my $self = shift;
    my $env  = shift;

    my $runner  = Dancer2::runner();
    my $request;
    my $request_built_successfully = eval {
        $EVAL_SHIM->(sub {
            $request = $runner->{'internal_request'} || $self->build_request($env);
        });
        1;
    };
    # Catch bad content causing deserialization to fail when building the request
    if ( ! $request_built_successfully ) {
        my $err = $@;
        Scalar::Util::weaken(my $app = $self);
        return Dancer2::Core::Error->new(
            app     => $app,
            message => $err,
            status  => 400,    # 400 Bad request (dont send again), rather than 500
        )->throw;
    }

    my $cname = $self->session_engine->cookie_name;
    my $defined_engines = $self->defined_engines;

DISPATCH:
    while (1) {
        my $http_method = lc $request->method;
        my $path_info   =    $request->path_info;

        # Add request to app and engines
        $self->set_request($request, $defined_engines);

        $self->log( core => "looking for $http_method $path_info" );

        ROUTE:
        foreach my $route ( @{ $self->routes->{$http_method} } ) {
            #warn "testing route " . $route->regexp . "\n";
            # TODO store in route cache

            # go to the next route if no match
            my $match = $route->match($request)
                or next ROUTE;

            $request->_set_route_params($match);
            $request->_set_route_parameters($match);
            $request->_set_route($route);

            # Add session to app *if* we have a session and the request
            # has the appropriate cookie header for _this_ app.
            if ( my $sess = $runner->{'internal_sessions'}{$cname} ) {
                $self->set_session($sess);
            }

            # calling the actual route
            my $response;

            # this is very evil, but allows breaking out of multiple stack
            # frames without throwing an exception.  Avoiding exceptions means
            # a naive eval won't swallow our flow control mechanisms, and
            # avoids __DIE__ handlers.  It also prevents some cleanup routines
            # from working, since they are expecting control to return to them
            # after an eval.
            DANCER2_CORE_APP_ROUTE_RETURN: {
                if (!$self->has_with_return) {
                    $self->set_with_return(sub {
                        $response = shift;
                        no warnings 'exiting';
                        last DANCER2_CORE_APP_ROUTE_RETURN;
                    });
                }
                $response = $self->_dispatch_route($route);
            };

            # ensure we clear the with_return handler
            $self->clear_with_return;

            # handle forward requests
            if ( ref $response eq 'Dancer2::Core::Request' ) {
                # this is actually a request, not response
                # however, we need to clean up the request & response
                $self->clear_request;
                $self->clear_response;

                # this is in case we're asked for an old-style dispatching
                if ( $runner->{'internal_dispatch'} ) {
                    # Get the session object from the app before we clean up
                    # the request context, so we can propagate this to the
                    # next dispatch cycle (if required).
                    $self->_has_session
                        and $runner->{'internal_sessions'}{$cname} =
                            $self->session;

                    $runner->{'internal_forward'} = 1;
                    $runner->{'internal_request'} = $response;
                    return $self->response_not_found($request);
                }

                $request = $response;
                next DISPATCH;
            }

            # from here we assume the response is a Dancer2::Core::Response

            # halted response, don't process further
            if ( $response->is_halted ) {
                $self->cleanup;
                delete $runner->{'internal_request'};
                return $response;
            }

            # pass the baton if the response says so...
            if ( $response->has_passed ) {
                ## A previous route might have used splat, failed
                ## this needs to be cleaned from the request.
                exists $request->{_params}{splat}
                    and delete $request->{_params}{splat};

                $response->has_passed(0); # clear for the next round

                # clear the content because if you pass it,
                # the next route is in charge of catching it
                $response->clear_content;
                next ROUTE;
            }

            # it's just a regular response
            $self->execute_hook( 'core.app.after_request', $response );
            $self->cleanup;
            delete $runner->{'internal_request'};

            return $response;
        }

        # we don't actually want to continue the loop
        last;
    }

    # No response! ensure Core::Dispatcher recognizes this failure
    # so it can try the next Core::App
    # and set the created request so we don't create it again
    # (this is important so we don't ignore the previous body)
    if ( $runner->{'internal_dispatch'} ) {
        $runner->{'internal_404'}     = 1;
        $runner->{'internal_request'} = $request;
    }

    # Render 404 response, cleanup, and return the response.
    my $response = $self->response_not_found($request);
    $self->cleanup;
    return $response;
}

sub build_request {
    my ( $self, $env ) = @_;

    # If we have an app, send the serialization engine
    my $request = Dancer2::Core::Request->new(
          env             => $env,
          is_behind_proxy => $self->settings->{'behind_proxy'} || 0,

          $self->has_serializer_engine
              ? ( serializer => $self->serializer_engine )
              : (),
    );

    return $request;
}

# Call any before hooks then the matched route.
sub _dispatch_route {
    my ( $self, $route ) = @_;

    local $@;
    eval {
        $EVAL_SHIM->(sub {
            $self->execute_hook( 'core.app.before_request', $self );
        });
        1;
    } or do {
        my $err = $@ || "Zombie Error";
        return $self->response_internal_error($err);
    };
    my $response = $self->response;

    if ( $response->is_halted ) {
        return $self->_prep_response( $response );
    }

    eval {
        $EVAL_SHIM->(sub{ $response = $route->execute($self) });
        1;
    } or do {
        my $err = $@ || "Zombie Error";
        return $self->response_internal_error($err);
    };

    return $response;
}

sub _prep_response {
    my ( $self, $response, $content ) = @_;

    # The response object has no back references to the content or app
    # Update the default_content_type of the response if any value set in
    # config so it can be applied when the response is encoded/returned.
    my $config = $self->config;
    if ( exists $config->{content_type}
      and my $ct = $config->{content_type} ) {
        $response->default_content_type($ct);
    }

    # if we were passed any content, set it in the response
    defined $content && $response->content($content);
    return $response;
}

sub response_internal_error {
    my ( $self, $error ) = @_;

    $self->execute_hook( 'core.app.route_exception', $self, $error );
    $self->log( error => "Route exception: $error" );

    local $Dancer2::Core::Route::REQUEST  = $self->request;
    local $Dancer2::Core::Route::RESPONSE = $self->response;

    return Dancer2::Core::Error->new(
        app       => $self,
        status    => 500,
        exception => $error,
    )->throw;
}

sub response_not_found {
    my ( $self, $request ) = @_;

    $self->set_request($request);

    local $Dancer2::Core::Route::REQUEST  = $self->request;
    local $Dancer2::Core::Route::RESPONSE = $self->response;

    my $response = Dancer2::Core::Error->new(
        app    => $self,
        status  => 404,
        message => $request->path,
    )->throw;

    $self->cleanup;

    return $response;
}

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

=attr with_return

Used to cache the coderef that will return from back to the dispatcher, across
an arbitrary number of stack frames.

=method has_session

Returns true if session engine has been defined and if either a session
object has been instantiated or if a session cookie was found and not
subsequently invalidated.

=attr destroyed_session

We cache a destroyed session here; once this is set we must not attempt to
retrieve the session from the cookie in the request.  If no new session is
created, this is set (with expiration) as a cookie to force the browser to
expire the cookie.

=method change_session_id

Changes the session ID used by the current session. This should be used on
any change of privilege level, for example on login. Returns the new session
ID.

=method destroy_session

Destroys the current session and ensures any subsequent session is created
from scratch and not from the request session cookie

=method register_plugin

=head2 lexical_prefix

Allow for setting a lexical prefix

    $app->lexical_prefix('/blog', sub {
        ...
    });

All the route defined within the callback will have a prefix appended to the
current one.

=method with_plugins( @plugin_names )

Creates instances of the given plugins and tie them to the app.
The plugin classes are automatically loaded.
Returns the newly created plugins.

The plugin names are expected to be without the leading C<Dancer2::Plugin>.
I.e., use C<Foo> to mean C<Dancer2::Plugin::Foo>.

If a given plugin is already tied to the app, the already-existing
instance will be used and returned by C<with_plugins> (think of it
as using a role).

    my @plugins = $app->with_plugins( 'Foo', 'Bar' );

    # now $app uses the plugins Dancer2::Plugin::Foo
    # and Dancer2::Plugin::Bar

=method with_plugin( $plugin_name )

Just like C<with_plugin>, but for a single plugin.

    my $plugin = $app->with_plugin('Foo');

=method add_route

Register a new route handler.

    $app->add_route(
        method  => 'get',
        regexp  => '/somewhere',
        code    => sub { ... },
        options => $conditions,
    );

Returns a new L<< Dancer2::Core::Route >> object created with the passed
arguments.

=method route_exists

Returns a true value if a route already exists, otherwise false.

    my $route = Dancer2::Core::Route->new(...);
    if ($app->route_exists($route)) {
        ...
    }

=method routes_regexps_for

Sugar for getting the ordered list of all registered route regexps by method.

    my $regexps = $app->routes_regexps_for( 'get' );

Returns an ArrayRef with the results.

=method redirect($destination, $status)

Sets a redirect in the response object.  If $destination is not an absolute URI, then it will
be made into an absolute URI, relative to the URI in the request.

=method halt

Flag the response object as 'halted'.

If called during request dispatch, immediately returns the response
to the dispatcher and after hooks will not be run.

=method pass

Flag the response object as 'passed'.

If called during request dispatch, immediately returns the response
to the dispatcher.

=method forward

Create a new request which is a clone of the current one, apart
from the path location, which points instead to the new location.
This is used internally to chain requests using the forward keyword.

This method takes 3 parameters: the url to forward to, followed by an
optional hashref of parameters added to the current request parameters,
followed by a hashref of options regarding the redirect, such as
C<method> to change the request method.

For example:

    forward '/login', { login_failed => 1 }, { method => 'GET' });

=method app

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

=head2 C< $SIG{__DIE__} > Compatibility via C< $Dancer2::Core::App::EVAL_SHIM >

If an installation wishes to use C< $SIG{__DIE__} > hooks to enhance
their error handling then it may be required to ensure that certain
bookkeeping code is executed within every C<eval BLOCK> that Dancer2
performs. This can be accomplished by overriding the global variable
C<$Dancer2::Core::App::EVAL_SHIM> with a subroutine which does whatever
logic is required.

This routine must perform the equivalent of the following subroutine:

    our $EVAL_SHIM = sub {
        my $code = shift;
        return $code->(@_);
    };

An example of overriding this sub might be as follows:

    $Dancer2::Core::App::EVAL_SHIM = sub {
        my $code = shift;
        local $IGNORE_EVAL_COUNTER = $IGNORE_EVAL_COUNTER + 1;
        return $code->(@_);
    };

B<Note:> that this is a GLOBAL setting, which must be set up before
any form of dispatch or use of Dancer2.

=cut
