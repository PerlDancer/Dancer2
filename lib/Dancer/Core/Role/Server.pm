package Dancer::Core::Role::Server;
use Moo::Role;

use Carp 'croak';
use Dancer::Moo::Types;

use Dancer::Core::App;
use Dancer::Core::Response;
use Dancer::Core::Request;
use Dancer::Core::Context;

has apps => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::ArrayRef(@_) },
    default => sub { [] },
);

sub register_application {
    my ($self, $app) = @_;
    push @{ $self->apps }, $app;
}

has host => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Str(@_) },
    default => sub { '0.0.0.0' },
);

has port => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Num(@_) },
    default => sub { 5000 },
);

has is_daemon => (
    is => 'ro',
    isa => sub { Dancer::Moo::Types::Bool(@_) },
    default => sub { 0 },
);

sub handle_request {
    my ($self, $env) = @_;

    foreach my $app (@{$self->apps}) {
        
        # initialize a context for the current request
        my $context = Dancer::Core::Context->new(env => $env);
        $app->context($context);

        my $route = $app->find_route_for_request($context->request);
        next if not defined $route; # might be in the next app

        my $content;
        my $response;

        # try to execute the route until we find one that did not pass
        while (1) {
            eval { $content = $route->execute($context) };
            return $self->response_internal_error($@) if $@; # 500

            # build a response with the return value of the route
            # and the response context
            $response = Dancer::Core::Response->new(
                content => $content,
                %{$context->response},
            );
            last unless $response->has_passed;

            # the route handler passed, play again with the next one...
            my $next = $route->next;
            return $self->response_not_found("last route passed") unless defined $next;

            # of course, we purge the response 'has_passed' flag in the context
            # (but not the rest of it, because we want all the context to
            # persist among all route handlers that pass.
            $context->response->{has_passed} = 0;
            $route = $next;
        }

        $app->context(undef);
        return $response->to_psgi;
    }

    return $self->response_not_found($env->{REQUEST_URI}) ; # 404
}

sub psgi_app {
    my ($self) = @_;
    sub {
        my ($env) = @_;
        $self->handle_request($env);
    };
}

sub response_internal_error {
    my ($self, $error) = @_;
    
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
