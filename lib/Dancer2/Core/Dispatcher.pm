package Dancer2::Core::Dispatcher;
# ABSTRACT: Class for dispatching request to the appropriate route handler

use Moo;
use Encode;

use Dancer2::Core::Types;
use Dancer2::Core::Context;
use Dancer2::Core::Response;

use Return::MultiLevel qw(with_return);

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
    my ( $self, $env, $request, $curr_context ) = @_;

#    warn "dispatching ".$env->{PATH_INFO}
#       . " with ".join(", ", map { $_->name } @{$self->apps });

    # Initialize a context for the current request
    # Once per dispatching! We should not create one context for each app or
    # we're going to parse the request body multiple times
    my $context = Dancer2::Core::Context->new(
        env => $env,
        ( request => $request ) x !! $request,
    );

    if ( $curr_context && $curr_context->has_session ) {
        $context->session( $curr_context->session );
    }

    foreach my $app ( @{ $self->apps } ) {

        # warn "walking through routes of ".$app->name;

        # set the current app in the context and context in the app..
        $context->app($app);
        $app->context($context);

        my $http_method = lc $context->request->method;
        my $path_info   = $context->request->path_info;

        $app->log( core => "looking for $http_method $path_info" );

      ROUTE:
        foreach my $route ( @{ $app->routes->{$http_method} } ) {

            # warn "testing route ".$route->regexp;

            # TODO store in route cache

            # go to the next route if no match
            my $match = $route->match( $context->request )
              or next ROUTE;

            $context->request->_set_route_params($match);

            my $response = with_return {
                my ($return) = @_;
                # stash the multilevel return coderef in the context
                $context->with_return($return) if ! $context->has_with_return;
                return $self->_dispatch_route($route, $context);
            };
            # Ensure we clear the with_return handler
            $context->clear_with_response;

            # No further processing of this response if its halted
            if ( $response->is_halted ) {
                $app->context(undef);
                return $response;
            }

            # pass the baton if the response says so...
            if ( $response->has_passed ) {

                ## A previous route might have used splat, failed
                ## this needs to be cleaned from the request.
                if (exists $context->request->{_params}{splat}) {
                    delete $context->request->{_params}{splat};
                }

                $response->has_passed(0);    # clear for the next round
                next ROUTE;
            }

            $app->execute_hook( 'core.app.after_request', $response );
            $app->context(undef);
            return $response;
        }
    }

    return $self->response_not_found($context);
}

# Call any before hooks then the matched route.
sub _dispatch_route {
    my ($self, $route, $context) = @_;
    my $app = $context->app;

    $app->execute_hook( 'core.app.before_request', $context );
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
            $app->log( error => "Route exception: $error" );
            $app->execute_hook(
                'core.app.route_exception', $context, $error);
            return $self->response_internal_error( $context, $error );
        }
    }

    # routes should use 'content_type' as default, or 'text/html'
    # (Content-Type header needs to be set to encode content below..)
    if ( !$response->header('Content-type') ) {
        if ( exists( $app->config->{content_type} ) ) {
            $response->header(
                'Content-Type' => $app->config->{content_type} );
        }
        else {
            $response->header(
                'Content-Type' => $self->default_content_type );
        }
    }
    if ( ref $content eq 'Dancer2::Core::Response' ) {
        $response = $context->response($content);
    }
    else {
        $response->content( defined $content ? $content : '' );
        $response->encode_content;
    }

    return $response;
}

sub response_internal_error {
    my ( $self, $context, $error ) = @_;

    # warn "got error: $error";

    return Dancer2::Core::Error->new(
        context      => $context,
        status       => 500,
        exception    => $error,
    )->throw;
}

# if we support 5.10.0 and up, we can change that
# for a 'state'
my $not_found_app;

sub response_not_found {
    my ( $self, $context ) = @_;

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
