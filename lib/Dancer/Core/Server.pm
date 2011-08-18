package Dancer::Core::Server;
use Carp 'croak';
use Moo;
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

sub backend { croak "backend attribute must be implemented" }

sub handle_request {
    my ($self, $request) = @_;

    foreach my $app (@{$self->apps}) {

        my $route = $app->find_route_for_request($request);
        next if not defined $route; # might be in the next app

        # route handler found, execute the request to get a response
        my $context = Dancer::Core::Context->new(request => $request);
        $app->context($context);

        my $content;
        eval { $content = $route->execute($context) };
        return $self->response_internal_error($@) if $@; # 500

        my $response = Dancer::Core::Response->new(
            content => $content,
            %{$context->response},
        );

        $app->context(undef);
        return $response->to_psgi;
    }

    return $self->response_not_found($request->path_info) ; # 404
}

sub psgi_app {
    my ($self) = @_;
    sub {
        my ($env) = @_;
        my $request = Dancer::Core::Request->new(env => $env);
        $self->handle_request($request);
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
