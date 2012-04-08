# ABSTRACT: TODO

package Dancer::Core::Dispatcher;
use Moo;
use Dancer::Moo::Types;

use Encode;
use Dancer::Core::Context;
use Dancer::Core::Response;

has apps => (
    is       => 'rw',
    isa      => sub { ArrayRef(@_) },
    default  => sub { [] },
);

has default_content_type => (
    is => 'ro',
    isa => sub { Str(@_) },
    default => sub { 'text/html' },
);

# take the list of applications and an $env hash, return a Response object.
sub dispatch {
    my ($self, $env, $request) = @_;
#    warn "dispatching ".$env->{PATH_INFO}
#       . " with ".join(", ", map { $_->name } @{$self->apps });

    # initialize a context for the current request
    # Once per didspatching! We should not create one context for each app or we're
    # going to parse multiple time the request body/
    my $context = Dancer::Core::Context->new(env => $env);

    foreach my $app (@{ $self->apps }) {
        # warn "walking through routes of ".$app->name;

        # set the current app in the context
        $context->app($app);

        $context->request($request) if defined $request;
        $app->context($context);

        my $http_method = lc $context->request->method;
        my $path_info   = $context->request->path_info;

        # warn "looking for $http_method $path_info";

        ROUTE:
        foreach my $route (@{ $app->routes->{$http_method} }) {
            # warn "testing route ".$route->regexp;

            # TODO next if $r->has_options && (not $r->validate_options($request));
            # TODO store in route cache

            # go to the next route if no match
            my $match = $route->match($http_method => $path_info) 
                or next ROUTE;

            $context->request->_set_route_params($match);

            # if the request has been altered by a before filter, we should not continue
            # with this route handler, we should continue to walk through the
            # rest
#            next if $context->request->path_info ne $path_info 
#                 || $context->request->method ne uc($http_method);

            $app->execute_hooks('core.app.before_request', $context);
            my $response = $context->response;

            my $content;
            if ( $response->is_halted ) {
                # if halted, it comes from the 'before' hook. Take its content
                $content = $response->content;
            }
            else {
                $content = eval { $route->execute($context) };
                return $self->response_internal_error($@) if $@;    # 500
            }

            # routes should use 'content_type' as default, or 'text/html'
            if (!$response->header('Content-type')) {
                if (exists($app->config->{content_type})) {
                    $response->header( 'Content-Type' => $app->config->{content_type} );
                } else {
                    $response->header( 'Content-Type' => $self->default_content_type );
                }
            }

            # serialize if needed
            $content = $app->config->{serializer}->serialize($content) 
                if ref $content and defined $app->config->{serializer}; 

            $response->content(defined $content ? $content : '');

            $response->encode_content;

            return $response if $response->is_halted;

            # pass the baton if the response says so...
            if ($response->has_passed) {
                $response->has_passed(0);  # clear for the next round
                next ROUTE;
            }

            $app->execute_hooks('core.app.after_request', $response);
            $app->context(undef);
            return $response;
        }
    }
    return $self->response_not_found($env->{PATH_INFO});
}

sub response_internal_error {
    my ($self, $error) = @_;
    
    # warn "got error: $error";

    my $r = Dancer::Core::Response->new( status => 500 );
    $r->content( "Internal Server Error\n\n$error\n" );
    $r->content_type ('text/plain');

    return $r;
}

sub response_not_found {
    my ($self, $request) = @_;
    
    my $r = Dancer::Core::Response->new( status => 404 );
    $r->content( "404 Not Found\n\n$request\n" );
    $r->content_type( 'text/plain' );

    return $r;
}

1;
