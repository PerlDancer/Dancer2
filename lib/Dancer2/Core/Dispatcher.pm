# ABSTRACT: Class for dispatching request to the appropriate route handler

package Dancer2::Core::Dispatcher;
use Moo;
use Encode;

use Dancer2::Core::Types;
use Dancer2::Core::Context;
use Dancer2::Core::Response;

has apps => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has default_content_type => (
    is      => 'ro',
    isa     => Str,
    default => sub {'text/html'},
);

# take the list of applications and an $env hash, return a Response object.
sub dispatch {
    my ($self, $env, $request, $curr_context) = @_;

#    warn "dispatching ".$env->{PATH_INFO}
#       . " with ".join(", ", map { $_->name } @{$self->apps });

# initialize a context for the current request
# Once per didspatching! We should not create one context for each app or we're
# going to parse multiple time the request body/
    my $context = Dancer2::Core::Context->new(env => $env);

    if($curr_context)
    {
        $context->session($curr_context->session);
    }

    foreach my $app (@{$self->apps}) {

        # warn "walking through routes of ".$app->name;

        # set the current app in the context
        $context->app($app);

        $context->request($request) if defined $request;
        $app->context($context);

        my $http_method = lc $context->request->method;
        my $path_info   = $context->request->path_info;

        $app->log(core => "looking for $http_method $path_info");

      ROUTE:
        foreach my $route (@{$app->routes->{$http_method}}) {

            # warn "testing route ".$route->regexp;

        # TODO next if $r->has_options && (not $r->validate_options($request));
        # TODO store in route cache

            # go to the next route if no match
            my $match = $route->match($http_method => $path_info)
              or next ROUTE;

            $context->request->_set_route_params($match);

            $context->request->deserialize
                if $context->request->serializer( $app->settings->{serializer} );

            # if the request has been altered by a before filter, we should not continue
            # with this route handler, we should continue to walk through the
            # rest

            # next if $context->request->path_info ne $path_info
            #         || $context->request->method ne uc($http_method);

            $app->execute_hook('core.app.before_request', $context);
            my $response = $context->response;

            my $content;
            if ($response->is_halted) {

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
                    $response->header(
                        'Content-Type' => $app->config->{content_type});
                }
                else {
                    $response->header(
                        'Content-Type' => $self->default_content_type);
                }
            }

            if (ref $content eq 'Dancer2::Core::Response') {
                $response = $context->response($content);
            }
            else {
                # serialize if needed
                # TODO make the response object self-serializable? With a
                # is_serialized attribute
                if ( my $serializer = ref($content) && $app->config->{serializer} ) {
                    $content = $serializer->serialize($content);
                    $response->content_type($serializer->content_type);
                }

                $response->content(defined $content ? $content : '');
                $response->encode_content;
            }

            return $response if $response->is_halted;

            # pass the baton if the response says so...
            if ($response->has_passed) {
                $response->has_passed(0);    # clear for the next round
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

    return Dancer2::Core::Error->new(
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
    my ($self, $context) = @_;

    $not_found_app ||= Dancer2::Core::App->new(
        name            => 'file_not_found',
        environment     => Dancer2->runner->environment,
        location        => Dancer2->runner->location,
        runner_config   => Dancer2->runner->config,
        postponed_hooks => Dancer2->runner->postponed_hooks,
        api_version     => 2,
    );

    $context->app($not_found_app);
    $not_found_app->context($context);

    return Dancer2::Core::Error->new(
        status  => 404,
        context => $context,
        message => $context->request->path,
    )->throw;
}

1;

__END__

=head1 SYNOPSIS

    use Dancer2::Core::Dispatcher;

    # Create an instance of dispatcher
    my $dispatcher = Dancer2::Core::Dispatcher->new( apps => [$app] );

    # Dispatch a request
    my $resp = $dispatcher->dispatch($env)->to_psgi;

    # Capture internal error of a response (if any) after a dispatch
    $dispatcher->response_internal_error($error);

    # Capture response not found for an application the after dispatch
    $dispatcher->response_not_found($context);

=head1 ATTRIBUTES

=head2 apps

The apps is an array reference to L<Dancer2::App>.

=head2 default_content_type

The default_content_type is a string which represents the context of the
request. This attribute is read-only.

=head1 METHODS

=head2 dispatch

The method C<dispatch> accepts the list of applications, hash reference of
the attribute B<env> of L<Dancer2::Request> and request as input arguments.

C<dispatch> returns a response object of L<Dancer2::Response>.

=head2 response_internal_error

The C<response_internal_error> takes as input the list of applications and
a variable error and returns an object of L<Dancer2::Error>.

=head2 response_not_found

The C<response_not_found> consumes as input the list of applications and an
object of type L<Dancer2::Context> and returns an object L<Dancer2::Error>.

