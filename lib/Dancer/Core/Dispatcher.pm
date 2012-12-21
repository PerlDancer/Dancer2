# ABSTRACT: TODO

package Dancer::Core::Dispatcher;
use Moo;
use Encode;

use Dancer::Core::Types;
use Dancer::Core::Context;
use Dancer::Core::Response;

has apps => (
    is       => 'rw',
    isa      => ArrayRef,
    default  => sub { [] },
);

has default_content_type => (
    is => 'ro',
    isa => Str,
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

        $app->log(core => "looking for $http_method $path_info");

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

            # next if $context->request->path_info ne $path_info
            #         || $context->request->method ne uc($http_method);

            $app->execute_hook('core.app.before_request', $context);
            my $response = $context->response;

            my $content;
            if ( $response->is_halted ) {
                # if halted, it comes from the 'before' hook. Take its content
                $content = $response->content;
            }
            else {
                $content = eval { $route->execute($context) };
                my $error = $@;
                if ($error) {
                    $app->log(error => "Route exception: $error");
                    return $self->response_internal_error($error);
                }
            }

            # routes should use 'content_type' as default, or 'text/html'
            if (!$response->header('Content-type')) {
                if (exists($app->config->{content_type})) {
                    $response->header( 'Content-Type' => $app->config->{content_type} );
                } else {
                    $response->header( 'Content-Type' => $self->default_content_type );
                }
            }

            if ( ref $content eq 'Dancer::Core::Response' ) {
                $response = $context->response($content);    
            }
            else {
                # serialize if needed
                if (defined $app->config->{serializer}) {
                    $content = $app->config->{serializer}->serialize($content)
                        if ref($content);
                }

                $response->content(defined $content ? $content : '');
                $response->encode_content;
            }

            return $response if $response->is_halted;

            # pass the baton if the response says so...
            if ($response->has_passed) {
                $response->has_passed(0);  # clear for the next round
                next ROUTE;
            }

            $app->execute_hook('core.app.after_request', $response);
            $app->context(undef);
            return $response;
        }
    }

    return $self->response_not_found($context);
}

sub response_internal_error {
    my ($self, $error) = @_;

    # warn "got error: $error";

    return Dancer::Core::Error->new(
        status       => 500,
        title        => 'Internal Server Error',
        content      => "Internal Server Error\n\n$error\n",
        content_type => 'text/plain'
    )->throw;
}

# if we support 5.10.0 and up, we can change that
# for a 'state'
my $not_found_app;

sub response_not_found {
    my ($self, $context ) = @_;

    $not_found_app ||= Dancer::Core::App->new(
        name            => 'file_not_found',
        environment     => Dancer->runner->environment,
        location        => Dancer->runner->location,
        runner_config   => Dancer->runner->config,
        postponed_hooks => Dancer->runner->postponed_hooks,
        api_version     => 2,
    );

    $context->app($not_found_app);
    $not_found_app->context($context);

    return Dancer::Core::Error->new( 
        status   => 404,
        context  => $context,
        message => $context->request->path,
    )->throw;
}

1;
