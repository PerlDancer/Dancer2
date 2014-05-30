package Dancer2::Core::Dispatcher;
# ABSTRACT: Class for dispatching request to the appropriate route handler

use Moo;
use Encode;

use Dancer2::Core::Types;
use Dancer2::Core::Context;
use Dancer2::Core::Request;
use Dancer2::Core::Response;

use Return::MultiLevel qw(with_return);

has apps => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

# take the list of applications and an $env hash, return a Response object.
sub dispatch {
    my ( $self, $env, $request, $curr_context ) = @_;

    # warn "dispatching ".$env->{PATH_INFO}
    #    . " with ".join(", ", map { $_->name } @{$self->apps });

    # Initialize a context for the current request
    # Once per dispatching! We should not create one context for each app or
    # we're going to parse the request body multiple times
    my $context = Dancer2::Core::Context->new();

    $curr_context and $curr_context->has_session
        and $context->session( $curr_context->session );

    foreach my $app ( @{ $self->apps } ) {
        # warn "walking through routes of ".$app->name;

        # set the current app in the context and context in the app..
        $context->app($app);
        $app->context($context);

        # create request if we didn't get any
        $request ||= $self->build_request( $env, $app );

        my $http_method = lc $request->method;
        my $path_info   =    $request->path_info;

        $app->log( core => "looking for $http_method $path_info" );

      ROUTE:
        foreach my $route ( @{ $app->routes->{$http_method} } ) {
            # warn "testing route ".$route->regexp;

            # TODO store in route cache

            # go to the next route if no match
            my $match = $route->match($request)
                or next ROUTE;

            $request->_set_route_params($match);
            $app->set_request($request);

            # FIXME: SHIM, to remove when Context.pm is removed
            $app->setup_context($context);
            $context->request($request);

            my $response = with_return {
                my ($return) = @_;

                # stash the multilevel return coderef in the context
                $app->has_with_return
                    or $app->with_return($return);

                return $self->_dispatch_route($route, $app);
            };

            # Ensure we clear the with_return handler
            $app->clear_with_response;

            # No further processing of this response if its halted
            if ( $response->is_halted ) {
                $app->context(undef);
                $app->cleanup;
                return $response;
            }

            # pass the baton if the response says so...
            if ( $response->has_passed ) {
                ## A previous route might have used splat, failed
                ## this needs to be cleaned from the request.
                exists $request->{_params}{splat}
                    and delete $request->{_params}{splat};

                $response->has_passed(0); # clear for the next round
                $app->cleanup;
                next ROUTE;
            }

            $app->execute_hook( 'core.app.after_request', $response );
            $app->context(undef);
            $app->cleanup;

            return $response;
        }
    }

    return $self->response_not_found( $env, $context );
}

# the dispatcher can build requests now :)
sub build_request {
    my ( $self, $env, $app ) = @_;

    # FIXME: SHIM, to remove when Context.pm is removed
    # this is needed to reset the env input fh to get data
    defined $env->{'psgi.input'}
        and $env->{'psgi.input'}->seek( 0, 0 );

    # If we have an app, send the serialization engine
    my $engine  = $app->engine('serializer');
    my $request = Dancer2::Core::Request->new(
          env             => $env,
          is_behind_proxy => Dancer2->runner->config->{'behind_proxy'} || 0,
        ( serializer      => $engine )x!! $engine,
    );

    # Log deserialization errors
    if ($engine) {
        $engine->has_error and $app->log(
            core => "Failed to deserialize the request : " .
                    $engine->error
        );
    }

    return $request;
}

# Call any before hooks then the matched route.
sub _dispatch_route {
    my ($self, $route, $app) = @_;

    $app->execute_hook( 'core.app.before_request', $app );
    my $response = $app->response;

    my $content;
    if ( $response->is_halted ) {
        # if halted, it comes from the 'before' hook. Take its content
        $content = $response->content;
    }
    else {
        $content = eval { $route->execute($app) };
        my $error = $@;
        if ($error) {
            $app->log( error => "Route exception: $error" );
            $app->execute_hook( 'core.app.route_exception', $app, $error );
            return $self->response_internal_error( $app, $error );
        }
    }

    if ( ref $content eq 'Dancer2::Core::Response' ) {
        $response = $app->set_response($content);
    }
    elsif ( defined $content ) {
        # The response object has no back references to the content or app
        # Update the default_content_type of the response if any value set in
        # config so it can be applied when the response is encoded/returned.
        if ( exists $app->config->{content_type}
          && $app->config->{content_type} ) {
            $response->default_content_type($app->config->{content_type});
        }
        $response->content($content);
        $response->encode_content;
    }

    return $response;
}

sub response_internal_error {
    my ( $self, $app, $error ) = @_;

    # warn "got error: $error";

    return Dancer2::Core::Error->new(
        app       => $app,
        status    => 500,
        exception => $error,
    )->throw;
}

# if we support 5.10.0 and up, we can change that
# for a 'state'
my $not_found_app;

sub response_not_found {
    my ( $self, $env, $context ) = @_;

    $not_found_app ||= Dancer2::Core::App->new(
        name            => 'file_not_found',
        # FIXME: are these two still global with the merging of
        #        feature/fix-remove-default-engine-config?
        environment     => Dancer2->runner->environment,
        location        => Dancer2->runner->location,
        runner_config   => Dancer2->runner->config,
        postponed_hooks => Dancer2->runner->postponed_hooks,
        api_version     => 2,
    );

    my $request = $self->build_request( $env, $not_found_app );
    $not_found_app->set_request($request);

    $context->request($request);
    $context->app($not_found_app);
    $not_found_app->context($context);

    return Dancer2::Core::Error->new(
        status  => 404,
        context => $context, # FIXME: go over Dancer2::Core::Error
        message => $request->path,
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
    $dispatcher->response_internal_error($context, $error);

    # Capture response not found for an application the after dispatch
    $dispatcher->response_not_found($context);

=head1 ATTRIBUTES

=head2 apps

The apps is an array reference to L<Dancer2::Core::App>.

=head2 default_content_type

The default_content_type is a string which represents the context of the
request. This attribute is read-only.

=head1 METHODS

=head2 dispatch

The C<dispatch> method accepts the list of applications, hash reference for
the B<env> attribute of L<Dancer2::Core::Request> and optionally the request
object and a context object as input arguments.

C<dispatch> returns a response object of L<Dancer2::Core::Response>.

Any before hook and matched route code is wrapped using L<Return::MultiLevel>
to allow DSL keywords such as forward and redirect to short-circuit remaining code
without having to throw an exception. L<Return::MultiLevel> will use L<Scope::Upper>
(an XS module) if it is available.

=head2 response_internal_error

The C<response_internal_error> takes as input the list of applications and
a variable error and returns an object of L<Dancer2::Core::Error>.

=head2 response_not_found

The C<response_not_found> consumes as input the list of applications and an
object of type L<Dancer2::Core::Context> and returns an object
L<Dancer2::Core::Error>.
