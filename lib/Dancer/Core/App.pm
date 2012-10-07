# ABSTRACT: TODO

package Dancer::Core::App;

use strict;
use warnings;

use Moo;
use File::Spec;
use Scalar::Util 'blessed';
use Carp 'croak';

use Dancer::FileUtils 'path', 'read_file_content';
use Dancer::Core::Types;
use Dancer::Core::Route;

# we have hooks here
with 'Dancer::Core::Role::Hookable';
with 'Dancer::Core::Role::Config';

sub supported_hooks {
    qw/
    core.app.before_request
    core.app.after_request
    /
}

has plugins => (
    is => 'rw',
    isa => ArrayRef,
    default => sub { [] },
);

sub register_plugin {
    my ($self, $plugin) = @_;
    Dancer::core_debug("Registered $plugin");
    push @{ $self->plugins }, $plugin;
}

around BUILDARGS => sub {
    my $orig = shift;
    my ( $class, %args ) = @_;
    $args{postponed_hooks} ||= {};
    return $class->$orig(%args);
};

has server => (
    is => 'rw',
    isa => ConsumerOf['Dancer::Core::Role::Server'],
    weak_ref => 1,
);

has location => (
    is      => 'ro',
    isa     => sub { -d $_[0] or croak "Not a regular location: $_[0]" },
    default => sub { File::Spec->rel2abs('.') },
);

sub _build_config_location { goto &location }

sub _build_environment {'development'}

has runner_config => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
);

has default_config => (
    is => 'ro',
    isa => HashRef,
    lazy => 1,
    builder => '_build_default_config',
);

sub _build_default_config {
    my ($self) = @_;

    return {   
        %{ $self->runner_config },
        template => 'Tiny',
        session => 'simple',
        route_handlers => {
            File => {
                public_dir => $ENV{DANCER_PUBLIC}
                  || path($self->config_location, 'public')
            },
            AutoPage => 1,
        },
    };
}

# This method overrides the default one from Role::Config

sub settings {
    my ($self) = @_;
    +{ %{Dancer->runner->config}, %{$self->config} }
}

sub engine {
    my ($self, $name) = @_;

    my $e = $self->settings->{$name};
    croak "No '$name' engine defined" if not defined $e;

    return $e;
}

sub session {
    my ($self, $key, $value) = @_;

    my $engine = $self->engine('session');

    my $session;

    # fetch any existing session
    my $cookie = $self->context->cookie($engine->name);
    if (defined $cookie && defined $cookie->value) {
        my $existing_session = $engine->retrieve($cookie->value);
        $session = $existing_session if defined $existing_session;
    }

    # create a new session
    if (! defined $session) {
        $session = $engine;
        $session->flush; # NOW?
        $self->context->response->push_header(
            'Set-Cookie' => $session->cookie->to_header);
    }

    # want the full session?
    return $session->data if @_ == 1;

    # session accessors
    return @_ == 3
        ? $session->write($key => $value)
        : $session->read($key);
}

sub template {
    my ($self) = shift;
    my $template = $self->engine('template');

    $template->context($self->context);
    my $content = $template->process(@_);
    $template->context(undef);

    return $content;
}

sub hook_candidates {
    my ($self) = @_;
    
    my @engines;
    for my $e (qw(logger serializer template logger)) {
        my $engine = eval { $self->engine($e) };
        push @engines, $engine if defined $engine;
    }

    my @route_handlers;
    for my $handler_name (keys %{$self->route_handlers}) {
        my $handler = $self->route_handlers->{$handler_name};
        push @route_handlers, $handler 
            if blessed($handler) && $handler->can('supported_hooks');
    }

    # TODO : get the list of all plugins registered
    my @plugins = @{ $self->plugins };

    (@route_handlers, @engines, @plugins);
}

sub all_hook_aliases {
    my ($self) = @_;

    my $aliases = $self->hook_aliases;
    for my $plugin (@{ $self->plugins }) {
        $aliases = {
            %{$aliases},
            %{ $plugin->hook_aliases },
        };
    }

    return $aliases;
}

has postponed_hooks => (
    is => 'ro',
    isa => HashRef,
    default => sub { {} },
);

# add_hook will add the hook to the first "hook candidate" it finds that support
# it. If none, then it will try to add the hook to the current application.
around add_hook => sub {
    my ($orig, $self) = (shift, shift);

    # saving caller information
    my ($package, $file, $line) = caller(4); # deep to 4 : user's app code
    my $add_hook_caller = [ $package, $file, $line ];

    my ($hook) = @_;
    my $name = $hook->name;
    my $hook_aliases = $self->all_hook_aliases;

    # look for an alias
    $name = $hook_aliases->{$name} 
        if defined $hook_aliases->{$name};
    $hook->name($name);

    # if that hook belongs to the app, register it now and return
    return $self->$orig(@_) if $self->has_hook($name);
    
    # at this point the hook name must be formated like:
    # '$type.$candidate.$name', eg: 'engine.template.before_render' or 
    # 'plugin.database.before_dbi_connect'
    my ($hookable_type, $hookable_name, $hook_name) = split (/\./, $name);

    croak "Invalid hook name `$name'" 
        unless defined $hookable_name && defined $hook_name;

    croak "Unknown hook type `$hookable_type'" 
        if ! grep /^$hookable_type$/, qw(core engine handler plugin);

    # register the hooks for existing hookable candidates
    foreach my $hookable ($self->hook_candidates) {
        $hookable->add_hook(@_) if $hookable->has_hook($name);
    }

    # we register the hook for upcoming objects;
    # that way, each components that can claim the hook will have a chance 
    # to register it.

    my $postponed_hooks = $self->postponed_hooks;

    # Hmm, so the hook was not claimed, at this point we'll cache it and
    # register it when the owner is instanciated
    $postponed_hooks->{$hookable_type}{$hookable_name} ||= {};
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name} ||= {};
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name}{hook} = $hook;
    $postponed_hooks->{$hookable_type}{$hookable_name}{$name}{caller} = $add_hook_caller;

};

around execute_hook => sub {
    my ($orig, $self) = (shift, shift);
    my ($hook, @args) = @_;
    unless ($self->has_hook($hook)) {
        foreach my $cand ($self->hook_candidates) {
            return $cand->execute_hook(@_) if $cand->has_hook($hook);
        }
    }

    return $self->$orig(@_);
};

sub mime_type {
    my ($self) = @_;
    my $runner = Dancer->runner;

    if (exists($self->config->{default_mime_type})) {
        $runner->mime_type->default($self->config->{default_mime_type});
    } else {
        $runner->mime_type->reset_default;
    }
    $runner->mime_type
}

sub log {
    my $self = shift;
    my $level = shift;

    my $logger = $self->setting('logger')
      or croak "No logger defined";

    $logger->$level(@_);
}

# XXX I think this should live on the context or response - but
# we don't currently have backwards links - weak_ref should make
# those completely doable.
#   -- mst

sub send_file {
    my ($self, $path, %options) = @_;
    my $env = $self->context->env;

    ($options{'streaming'} && ! $env->{'psgi.streaming'}) and
        croak "Streaming is not supported on this server.";

    (exists $options{'content_type'}) and
        $self->context->response->header(
            'Content-Type' => $options{content_type}
        );

    (exists $options{filename}) and
        $self->context->response->header(
            'Content-Disposition' =>
                "attachment; filename=\"$options{filename}\""
        );

    # if we're given a SCALAR reference, we're going to send the data
    # pretending it's a file (on-the-fly file sending)
    (ref($path) eq 'SCALAR') and
        return $$path;

    my $file_handler = Dancer::Handler::File->new(
        app => $self,
        postponed_hooks => $self->postponed_hooks,
        public_dir => ($options{system_path} ? File::Spec->rootdir : undef ),
    );

    for my $h (keys %{ $self->route_handlers->{File}->hooks } ) {
        my $hooks = $self->route_handlers->{File}->hooks->{$h};
        $file_handler->replace_hook($h, $hooks);
    }

    $self->context->request->path_info($path);
    return $file_handler->code->($self->context, $self->prefix);
    
    # TODO Streaming support
}


sub BUILD {
    my ($self) = @_;
    $self->init_route_handlers();
}

sub finish {
    my ($self) = @_;
    $self->register_route_handlers;
    $self->compile_hooks;
}

has route_handlers => (
    is => 'rw',
    isa => HashRef,
    default => sub { {} },
);

sub init_route_handlers {
    my ($self) = @_;

    my $handlers_config = $self->config->{route_handlers};
    for my $handler_name (keys %{$handlers_config}) {
        my $config = $handlers_config->{$handler_name};
        $config = {} if !ref($config);
        $config->{app} = $self;
        my $handler = Dancer::Factory::Engine->create(
            Handler => $handler_name,
            %$config,
            postponed_hooks => $self->postponed_hooks,
            );
        $self->route_handlers->{$handler_name} = $handler;
    }
}

sub register_route_handlers {
    my ($self) = @_;
    for my $handler_name (keys %{ $self->route_handlers }) {
        my $handler = $self->route_handlers->{$handler_name};
        $handler->register($self);
    }
}

sub compile_hooks {
    my ($self) = @_;

    for my $position ($self->supported_hooks) {
        my $compiled_hooks = [];
        for my $hook (@{ $self->hooks->{$position} }) {
            my $compiled = sub {
                # don't run the filter if halt has been used
                return if $self->context->response->is_halted;

                # TODO: log entering the hook '$position'
                #warn "entering hook '$position'";
                eval { $hook->(@_) };

                # TODO : do something with exception there
                croak "Exception caught in '$position' filter: $@" if $@;
            };

            push @{$compiled_hooks}, $compiled;
        }
        $self->replace_hook($position, $compiled_hooks);
    }
}

has name => (
    is => 'ro',
    isa => Str,
);

# holds a context whenever a request is processed
has context => (
    is => 'rw',
    isa => Maybe[InstanceOf['Dancer::Core::Context']],
);

has prefix => (
    is => 'rw',
    isa => DancerPrefix,
    coerce => sub {
        my ($prefix) = @_;
        return undef if defined($prefix) and $prefix eq "/";
        return $prefix;
    },
);

=head2 lexical_prefix

Allow for setting a lexical prefix

    $app->lexical_prefix('/blog', sub {
        ...
    });

All the route defined within the callback will have a prefix appended to the
current one.

=cut

sub lexical_prefix {
    my ($self, $prefix, $cb) = @_;
    undef $prefix if $prefix eq '/';

    # save the app prefix
    my $app_prefix = $self->prefix;

    # alter the prefix for the callback
    my $new_prefix =
        (defined $app_prefix ? $app_prefix : '')
      . (defined $prefix     ? $prefix     : '');

    # if the new prefix is empty, it's a meaningless prefix, just ignore it
    $self->prefix($new_prefix) if length $new_prefix;

    eval { $cb->() };
    my $e = $@;

    # restore app prefix
    $self->prefix( $app_prefix );

    croak "Unable to run the callback for prefix '$prefix': $e"
        if $e;
}

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

=head2 add_route

Register a new route handler.

    $app->add_route(
        method => 'get',
        regexp => '/somewhere',
        code => sub { ... }
    );

=cut

sub add_route {
    my ($self, %route_attrs) = @_;

    my $route = Dancer::Core::Route->new(
        %route_attrs,
        prefix => $self->prefix,
    );

    my $method = $route->method;
    push @{ $self->routes->{$method} }, $route;
}

=head2 routes_regexps_for

Sugar for getting the ordered list of all registered route regexps by method.

    my $regexps = $app->routes_regexps_for( 'get' );

Returns an ArrayRef with the results.

=cut

sub routes_regexps_for {
    my ($self, $method) = @_;
    return [
        map { $_->regexp } @{ $self->routes->{$method} }
    ];
}

1;
