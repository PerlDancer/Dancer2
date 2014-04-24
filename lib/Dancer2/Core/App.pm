# ABSTRACT: encapsulation of Dancer2 packages
package Dancer2::Core::App;

use Moo;
use File::Spec;
use Scalar::Util 'blessed';
use Carp 'croak';

use Dancer2::FileUtils 'path', 'read_file_content';
use Dancer2::Core;
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
                my ( $self, $value, $config ) = @_;
                $self->template_engine->views($value);
            },

            layout => sub {
                my ( $self, $value, $config ) = @_;
                $self->template_engine->layout($value);
            },
        };

        foreach my $engine ( @{ $self->supported_engines } ) {
            $triggers->{$engine} = sub {
                my ( $self, $value, $config ) = @_;

                return $value if ref $value;

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
    my ($self, $value, $config) = @_;

    $config = $self->config     if !defined $config;
    $value  = $config->{logger} if !defined $value;

    return $value if ref($value);

    # XXX This is needed for the tests that create an app without
    # a runner.
    $value = 'console' if !defined $value;

    my $engine_options =
        $self->_get_config_for_engine( logger => $value, $config );

    my $logger = Dancer2::Core::Factory->create(
        logger => $value,
        %{$engine_options},
        app_name        => $self->name,
        postponed_hooks => $self->get_postponed_hooks
    );

    $logger->log_level($config->{log}) if exists $config->{log};

    return $logger;
}

sub _build_session_engine {
    my ($self, $value, $config)  = @_;

    $config = $self->config        if !defined $config;
    $value  = $config->{'session'} if !defined $value;

    $value = 'simple' if !defined $value;
    return $value     if ref($value);

    my $engine_options =
          $self->_get_config_for_engine( session => $value, $config );

    return Dancer2::Core::Factory->create(
        session => $value,
        %{$engine_options},
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _build_template_engine {
    my ($self, $value, $config)  = @_;

    $config = $self->config         if !defined $config;
    $value  = $config->{'template'} if !defined $value;

    return undef  if !defined $value;
    return $value if ref($value);

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
    my ($self, $value, $config) = @_;

    $config = $self->config         if !defined $config;
    $value  = $config->{serializer} if !defined $value;

    return undef  if !defined $value;
    return $value if ref($value);

    my $engine_options =
        $self->_get_config_for_engine( serializer => $value, $config );

    return Dancer2::Core::Factory->create(
        serializer      => $value,
        config          => $engine_options,
        postponed_hooks => $self->get_postponed_hooks,
    );
}

sub _get_config_for_engine {
    my ( $self, $engine, $name, $config ) = @_;

    my $default_config = {
        environment => $self->environment,
        location    => $self->config_location,
    };

    defined $config->{'engines'} && defined $config->{'engines'}{$engine}
        or return $default_config;

    my $engine_config = {};

    # XXX we need to move the camilize function out from Core::Factory
    # - Franck, 2013/08/03
    for my $config_key ($name, Dancer2::Core::camelize($name)) {
        $engine_config = $config->{engines}{$engine}{$config_key}
            if defined $config->{engines}->{$engine}{$config_key};
    }
    return { %{$default_config}, %{$engine_config}, } || $default_config;
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

has server => (
    is       => 'rw',
    isa      => ConsumerOf ['Dancer2::Core::Role::Server'],
    weak_ref => 1,
);

has runner_config => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has default_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_default_config',
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

# holds a context whenever a request is processed
has context => (
    is      => 'rw',
    isa     => Maybe [ InstanceOf ['Dancer2::Core::Context'] ],
    trigger => sub {
        my ( $self, $ctx ) = @_;
        $self->_init_for_context($ctx),;
        for my $type ( @{ $self->supported_engines } ) {
            my $attr   = "${type}_engine";
            my $engine = $self->$attr or next;
            defined($ctx) ? $engine->context($ctx) : $engine->clear_context;
        }
    },
);

has prefix => (
    is        => 'rw',
    isa       => Maybe [Dancer2Prefix],
    predicate => 1,
    coerce    => sub {
        my ($prefix) = @_;
        return undef if defined($prefix) and $prefix eq "/";
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
    my ( $orig, $self ) = ( shift, shift );

    # saving caller information
    my ( $package, $file, $line ) = caller(4);    # deep to 4 : user's app code
    my $add_hook_caller = [ $package, $file, $line ];

    my ($hook)       = @_;
    my $name         = $hook->name;
    my $hook_aliases = $self->all_hook_aliases;

    # look for an alias
    $name = $hook_aliases->{$name}
      if defined $hook_aliases->{$name};
    $hook->name($name);

    # if that hook belongs to the app, register it now and return
    return $self->$orig(@_) if $self->has_hook($name);

    # at this point the hook name must be formatted like:
    # '$type.$candidate.$name', eg: 'engine.template.before_render' or
    # 'plugin.database.before_dbi_connect'
    my ( $hookable_type, $hookable_name, $hook_name ) = split( /\./, $name );

    croak "Invalid hook name `$name'"
      unless defined $hookable_name && defined $hook_name;

    croak "Unknown hook type `$hookable_type'"
      if !grep /^$hookable_type$/, qw(core engine handler plugin);

    # register the hooks for existing hookable candidates
    foreach my $hookable ( $self->hook_candidates ) {
        $hookable->add_hook(@_) if $hookable->has_hook($name);
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
    my ( $orig, $self ) = ( shift, shift );
    my ( $hook, @args ) = @_;
    if ( !$self->has_hook($hook) ) {
        foreach my $cand ( $self->hook_candidates ) {
            return $cand->execute_hook(@_) if $cand->has_hook($hook);
        }
    }

    return $self->$orig(@_);
};

sub _build_default_config {
    my ($self) = @_;

    return {
        %{ $self->runner_config },
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
    my ($self) = @_;

 # Hook to flush the session at the end of the request, this way, we're sure we
 # flush only once per request
    $self->add_hook(
        Dancer2::Core::Hook->new(
            name => 'core.app.after_request',
            code => sub {
                my $response = shift;

                # make sure an engine is defined, if not, nothing to do
                my $engine = $self->session_engine;
                return if !defined $engine;

                # make sure we have a context to examine
                return if !defined $self->context;

                # if a session has been instantiated or we already had a
                # session, first flush the session so cookie-based sessions can
                # update the session ID if needed, then set the session cookie
                # in the response

                if ( $self->context->has_session ) {
                    my $session = $self->context->session;
                    $engine->flush( session => $session )
                      if $session->is_dirty;
                    $engine->set_cookie_header(
                        response => $response,
                        session  => $session
                    );
                }
                elsif ( $self->context->has_destroyed_session ) {
                    my $session = $self->context->destroyed_session;
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

sub _init_for_context {
    my ($self) = @_;

    return if !defined $self->context;
    return if !defined $self->context->request;

    $self->context->request->is_behind_proxy(1)
      if $self->setting('behind_proxy');
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
    my ( $self, $plugin ) = @_;
    $self->log( core => "Registered $plugin");
    push @{ $self->plugins }, $plugin;
}

# This method overrides the default one from Role::Config
sub settings {
    my ($self) = @_;
    +{ %{ Dancer2->runner->config }, %{ $self->config } };
}

sub engine {
    my ( $self, $name ) = @_;

    croak "Engine '$name' is not supported."
        if !grep {$_ eq $name} @{ $self->supported_engines };

    my $attr_name = "${name}_engine";
    return $self->$attr_name;
}

sub session {
    my ( $self, $key, $value ) = @_;

    # shortcut reads if no session exists, so we don't
    # instantiate sessions for no reason
    if ( @_ == 2 ) {
        return unless $self->context->has_session;
    }

    my $session = $self->context->session;
    croak "No session available, a session engine needs to be set"
      if !defined $session;

    # return the session object if no key
    return $session if @_ == 1;

    # read if a key is provided
    return $session->read($key) if @_ == 2;

    # write to the session or delete if value is undef
    if ( defined $value ) {
        $session->write( $key => $value );
    }
    else {
        $session->delete($key);
    }
}

sub template {
    my ($self) = shift;
    my $template = $self->template_engine;

    my $content = $template->process(@_);

    return $content;
}

sub hook_candidates {
    my ($self) = @_;

    my @engines;
    for my $e ( @{ $self->supported_engines } ) {
        my $attr   = "${e}_engine";
        my $engine = $self->$attr or next;
        push @engines, $engine;
    }

    my @route_handlers;
    for my $handler ( @{ $self->route_handlers } ) {
        my $handler_code = $handler->{handler};
        push @route_handlers, $handler_code
          if blessed($handler_code) && $handler_code->can('supported_hooks');
    }

    # TODO : get the list of all plugins registered
    my @plugins = @{ $self->plugins };

    ( @route_handlers, @engines, @plugins );
}

sub all_hook_aliases {
    my ($self) = @_;

    my $aliases = $self->hook_aliases;
    for my $plugin ( @{ $self->plugins } ) {
        $aliases = { %{$aliases}, %{ $plugin->hook_aliases }, };
    }

    return $aliases;
}

sub mime_type {
    my ($self) = @_;
    my $runner = Dancer2->runner;

    if ( exists( $self->config->{default_mime_type} ) ) {
        $runner->mime_type->default( $self->config->{default_mime_type} );
    }
    else {
        $runner->mime_type->reset_default;
    }
    $runner->mime_type;
}

sub log {
    my ($self, $level, @args)  = @_;

    my $logger = $self->logger_engine
      or croak "No logger defined";

    $logger->$level(@args);
}

# XXX I think this should live on the context or response - but
# we don't currently have backwards links - weak_ref should make
# those completely doable.
#   -- mst

sub send_file {
    my ( $self, $path, %options ) = @_;
    my $env = $self->context->env;

    ( $options{'streaming'} && !$env->{'psgi.streaming'} )
      and croak "Streaming is not supported on this server.";

    ( exists $options{'content_type'} )
      and $self->context->response->header(
        'Content-Type' => $options{content_type} );

    ( exists $options{filename} )
      and $self->context->response->header( 'Content-Disposition' =>
          "attachment; filename=\"$options{filename}\"" );

    # if we're given a SCALAR reference, we're going to send the data
    # pretending it's a file (on-the-fly file sending)
    ( ref($path) eq 'SCALAR' )
      and return $$path;

    my $conf = {};
    $conf->{app} = $self;
    my $file_handler = Dancer2::Core::Factory->create(
        Handler => 'File',
        %$conf,
        postponed_hooks => $self->postponed_hooks,
        public_dir => ( $options{system_path} ? File::Spec->rootdir : undef ),
    );

    # List shouldn't be too long, so we use 'grep' instead of 'first'
    if (my ($handler) = grep { $_->{name} eq 'File' } @{$self->route_handlers}) {
        for my $h ( keys %{ $handler->{handler}->hooks } ) {
            my $hooks = $handler->{handler}->hooks->{$h};
            $file_handler->replace_hook( $h, $hooks );
        }
    }

    $self->context->request->path_info($path);
    return $file_handler->code->( $self->context, $self->prefix );

    # TODO Streaming support
}


sub BUILD {
    my ($self) = @_;
    $self->init_route_handlers();
    $self->_init_hooks();
}

sub finish {
    my ($self) = @_;
    $self->register_route_handlers;
    $self->compile_hooks;
}

sub init_route_handlers {
    my ($self) = @_;

    my $handlers_config = $self->config->{route_handlers};
    for my $handler_data ( @{$handlers_config} ) {
        my ($handler_name, $config) = @{$handler_data};
        $config = {} if !ref($config);
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
    my ($self) = @_;
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
                return
                  if ( $self->context && $self->context->response->is_halted );

                eval { $hook->(@_) };

                # TODO : do something with exception there
                croak "Exception caught in '$position' filter: $@" if $@;
            };

            push @{$compiled_hooks}, $compiled;
        }
        $self->replace_hook( $position, $compiled_hooks );
    }
}

sub lexical_prefix {
    my ( $self, $prefix, $cb ) = @_;
    undef $prefix if $prefix eq '/';

    # save the app prefix
    my $app_prefix = $self->prefix;

    # alter the prefix for the callback
    my $new_prefix =
        ( defined $app_prefix ? $app_prefix : '' )
      . ( defined $prefix     ? $prefix     : '' );

    # if the new prefix is empty, it's a meaningless prefix, just ignore it
    $self->prefix($new_prefix) if length $new_prefix;

    eval { $cb->() };
    my $e = $@;

    # restore app prefix
    $self->prefix($app_prefix);

    croak "Unable to run the callback for prefix '$prefix': $e"
      if $e;
}

sub add_route {
    my ( $self, %route_attrs ) = @_;

    my $route =
      Dancer2::Core::Route->new( %route_attrs, prefix => $self->prefix, );

    my $method = $route->method;

    push @{ $self->routes->{$method} }, $route;
}

sub route_exists {
    my ( $self, $route ) = @_;

    my $routes = $self->routes->{ $route->method };

    foreach my $existing_route (@$routes) {
        return 1 if $existing_route->spec_route eq $route->spec_route;
    }
    return 0;
}

sub routes_regexps_for {
    my ( $self, $method ) = @_;
    return [ map { $_->regexp } @{ $self->routes->{$method} } ];
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

=attr server

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
