package Dancer::Core::App;

use strict;
use warnings;

use Moo;
use Carp;
use Dancer::FileUtils 'path';
use Dancer::Moo::Types;

use Dancer::Core::Route;

# we have hooks here
with 'Dancer::Core::Role::Hookable';
with 'Dancer::Core::Role::Config';

sub default_config { {} }

# we dont support per-app config files yet (but that could be easy to do in the
# future)
sub config_location { undef }
sub get_environment { undef }

sub supported_hooks { 
    qw/before after before_serializer after_serializer before_file_render after_file_render/
}

sub BUILD {
    my ($self) = @_;
    $self->install_hooks($self->supported_hooks);
}

sub compile_hooks {
    my ($self) = @_;
    
    for my $position ($self->supported_hooks) {
        my $compiled_hooks = [];
        for my $hook (@{ $self->hooks->{$position} }) {
            my $compiled = sub {
                # don't run the filter if halt has been used
                return if $self->context->response->{is_halted};
                
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
        code => sub { ... });

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
