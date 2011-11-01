package Dancer::Core::App;

use strict;
use warnings;

use Moo;
use File::Spec;
use Scalar::Util 'blessed';
use Carp 'croak';

use Dancer::FileUtils 'path', 'read_file_content';
use Dancer::Moo::Types;
use Dancer::Core::Route;

# we have hooks here
with 'Dancer::Core::Role::Hookable';
with 'Dancer::Core::Role::Config';

has location => (
    is => 'ro',
    isa => sub { -d $_[0] or croak "Not a regular location: $_[0]" },
    default => sub { File::Spec->rel2abs('.') },
);

has runner_config => (
    is => 'ro',
    isa => sub { HashRef(@_) },
    default => sub { {} },
);

has default_config => (
    is => 'ro',
    isa => sub { HashRef(@_) },
    lazy => 1,
    builder => '_build_default_config',
);

sub _build_default_config {
    my ($self) = @_;

    return {   
        %{ $self->runner_config },
        route_handlers => {
            File => {
                public_dir => $ENV{DANCER_PUBLIC}
                  || path($self->location, 'public')
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

sub template {
    my ($self) = shift;
    my $template = $self->engine('template');

    $template->context($self->context);
    my $content = $template->process(@_);
    $template->context(undef);

    return $content;
}

# we dont support per-app config files yet
# (but that could be easy to do in the future)
sub config_location { undef }
sub get_environment { undef }

sub supported_hooks {
    qw/before after before_request after_request/
}

sub _hook_candidates {
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
    my @plugins;

    (@route_handlers, @engines, @plugins);
}

around add_hook => sub {
    my ($orig, $self) = (shift, shift);
    my ($hook) = @_;
    unless ($self->has_hook(my $name = $hook->name)) {
        foreach my $cand ($self->_hook_candidates) {
            return $cand->add_hook(@_) if $cand->has_hook($name);
        }
    }

    return $self->$orig(@_);
};

around execute_hooks => sub {
    my ($orig, $self) = (shift, shift);
    my ($hook, @args) = @_;
    unless ($self->has_hook($hook)) {
        foreach my $cand ($self->_hook_candidates) {
            return $cand->execute_hooks(@_) if $cand->has_hook($hook);
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
        public_dir => ($options{system_path} ? File::Spec->rootdir : undef ),
    ); 

    for my $h (keys %{ $self->route_handlers->{File}->hooks } ) {
        my $hooks = $self->route_handlers->{File}->hooks->{$h};
        $file_handler->replace_hooks($h, $hooks);
    }

    $self->context->request->path_info($path);
    return $file_handler->code->($self->context, $self->prefix);
    
    # TODO Streaming support
}


sub BUILD {
    my ($self) = @_;
    $self->install_hooks($self->supported_hooks);
    $self->init_route_handlers();
}

sub finish {
    my ($self) = @_;
    $self->register_route_handlers;
    $self->compile_hooks;
}

has route_handlers => (
    is => 'rw',
    isa => sub { HashRef(@_) },
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
            Handler => $handler_name, %$config);
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
        $self->replace_hooks($position, $compiled_hooks);
    }
}

has name => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Str(@_) },
);

# holds a context whenever a request is processed
has context => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Context', @_) },
);

has prefix => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::DancerPrefix(@_) },
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
    isa     => sub { Dancer::Moo::Types::HashRef(@_) },
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
