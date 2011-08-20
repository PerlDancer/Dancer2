package Dancer::Core::Dispatcher;
use Moo;
use Dancer::Moo::Types;

use Dancer::Core::Context;
use Dancer::Core::Response;

has apps => (
    is       => 'rw',
    isa      => sub { ArrayRef(@_) },
    default  => sub { [] },
);

# take the list of applications and an $env hash, return a Response object.
sub dispatch {
    my ($self, $env) = @_;
    # warn "dispatching ".$env->{PATH_INFO}
    #   . " with ".join(", ", map { $_->name } @{$self->apps });

    foreach my $app (@{ $self->apps }) {
        # warn "walking through routes of ".$app->name;

        # initialize a context for the current request
        my $context = Dancer::Core::Context->new(env => $env);
        $app->context($context);

        my $http_method = lc $context->request->method;
        my $path_info   = $context->request->path_info;

        # warn "looking for $http_method $path_info";

        foreach my $route (@{ $app->routes->{$http_method} }) {
            # warn "testing route ".$route->regexp;

            # TODO next if $r->has_options && (not $r->validate_options($request));
            # TODO store in route cache

            my $match = $route->match($http_method => $path_info);
            if ($match) {
                # warn "got a match";
                $context->request->_set_route_params($match);
            }

            $app->execute_hooks('before', $context);

            # if the request has been altered by a before filter, we should not continue
            # with this route handler, we should continue to walk through the
            # rest
            next if $context->request->path_info ne $path_info 
                 || $context->request->method ne uc($http_method);
            
            # go to the next route if no match
            next if !$match;

            my $content;
            my $response;

            eval { $content = $route->execute($context) };
            return $self->response_internal_error($@) if $@; # 500

            # build a response with the return value of the route
            # and the response context
            $response = Dancer::Core::Response->new(
                content => $content,
                %{$context->response},
            );

            # pass the baton if the response says so... 
            if ($response->has_passed) {
                $context->response->{has_passed} = 0;
                next;
            }
        
            $app->execute_hooks('after', $response);
            $app->context(undef);
            return $response->to_psgi;
        }
    }
    return $self->response_not_found($env->{PATH_INFO});
}

sub response_internal_error {
    my ($self, $error) = @_;
    
    # warn "got error: $error";

    my $r = Dancer::Core::Response->new(
        status => 500,
        content => "Internal Server Error\n\n$error\n",
        content_type => 'text/plain',
    );

    return $r->to_psgi;
}

sub response_not_found {
    my ($self, $request) = @_;
    
    my $r = Dancer::Core::Response->new(
        status => 404,
        content => "404 Not Found\n\n$request\n",
        content_type => 'text/plain',
    );

    return $r->to_psgi;
}

1;
