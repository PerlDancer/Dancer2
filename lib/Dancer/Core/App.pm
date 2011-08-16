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
    trigger => sub {
        my ($self, $name) = @_;
        warn "App $name is created ($self)";
    },
);

has prefix => (
    is => 'rw', 
    isa => sub { Dancer::Moo::Types::DancerPrefix(@_) },
    trigger => sub {
        my ($self, @attrs) = @_;
        $self->_set_prefix(@attrs);
    },
);

sub _set_prefix {
    my ($self, $prefix, $cb) = @_;
    
    # reject '/' 
    return undef $self->{prefix} 
        if defined($prefix) and $prefix eq "/";

    # handle lexical prefixes
    # eg: any route defined in $cb should have the prefix append to the current one
    return if ref($cb) ne 'CODE';
    
    # save the app prefix
    my $app_prefix = $self->prefix;
    $self->{prefix} = $app_prefix.$prefix;
    
    eval { $cb->() };
    my $e = $@;
    
    # restore app prefix
    $self->{prefix} = $app_prefix;
    
    croak "Unable to run the callback for prefix '$prefix': $e" 
        if $e;
}

# routes registry, stored by method:
# { get => [ ], ... }
has routes => (
    is => 'rw', 
    isa => sub { Dancer::Moo::Types::HashRef(@_) },
    default => sub { {} },
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

        my $route;
        eval { 
            $route = Dancer::Core::Route->new(
                %route_attrs, 
                prefix => $self->prefix,
            ); 
        };
        croak "Unable to register route: $@"
          if $@;
        
        my $method = $route->method;
        my $reg = $self->routes->{$method} ||= [];
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

    my $method = $request->method;
    my $path   = $request->path_info;
    my @routes = @{ $self->routes->{$method} };

    for my $r (@routes) {
        my $match = $r->match($method, $path);

        if ($match) {
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
