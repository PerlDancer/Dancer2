package Dancer::Core::App;

use strict;
use warnings;

use Moo;
use Dancer::Moo::Types;
use Carp;

use Dancer::Core::Route;

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

        # chain the route handlers, will be handy for the pass
        # feature
        my $previous = $self->routes->{$method}->[-1];
        $route->previous($previous) if defined $previous;

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

=head2 find_route_for_request

Search for the first matching route handler in the application's registry for
the given request.

    my $route = $app->find_route_for_request($request);

Return a L<Dancer::Core::Route> object if found, undef if not.

=cut

sub find_route_for_request {
    my ($self, $request) = @_;

# TODO
#    # if route cache is enabled, we check if we handled this path before
#    if (Dancer::Config::setting('route_cache')) {
#        my $route = Dancer::Route::Cache->get->route_from_path($method,
#            $request->path_info);
#
#        # NOTE maybe we should cache the match data as well
#        if ($route) {
#            $route->match($request);
#            return $route;
#        }
#    }

    my $method = lc($request->method);
    my $path   = $request->path_info;
    my @routes = @{ $self->routes->{$method} };

    for my $r (@routes) {
        my $match = $r->match($method, $path);

        if ($match) {
            # save the match data in the request params
            $request->_set_route_params($match);
            
            # TODO next if $r->has_options && (not $r->validate_options($request));

#            # if we have a route cache, store the result
#            if (Dancer::Config::setting('route_cache')) {
#                Dancer::Route::Cache->get->store_path($method,
#                    $request->path_info => $r);
#            }

            return $r;
        }
    }
    return;
}

#sub setting {
#    my $self = shift;
#
#    if ($self->name eq 'main') {
#        return (@_ > 1)
#          ? Dancer::Config::setting( @_ )
#          : Dancer::Config::setting( $_[0] );
#    }
#
#    if (@_ > 1) {
#        $self->_set_settings(@_)
#    } else {
#        my $name = shift;
#        exists($self->settings->{$name}) ? $self->settings->{$name}
#          : Dancer::Config::setting($name);
#    }
#}

#sub _set_settings {
#    my $self = shift;
#    die "Odd number of elements in set" unless @_ % 2 == 0;
#    while (@_) {
#        my $name = shift;
#        my $value = shift;
#        $self->settings->{$name} =
#          Dancer::Config->normalize_setting($name => $value);
#    }
#}
1;
