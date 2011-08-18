package Dancer::Core::Server;
use Carp 'croak';
use Moo;
use Dancer::Moo::Types;

use Dancer::Core::App;
use Dancer::Core::Response;
use Dancer::Core::Request;
use Dancer::Core::Context;

has app => (
    is => 'ro',
    required => 1,
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::App' => @_) },
);

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
    my $app = $self->app;
    
    my $route = $app->find_route_for_request($request);
    return $app->response_not_found() if ! defined $route; # 404

    my $context = Dancer::Core::Context->new(request => $request);
    $app->context($context);

    my $content;
    eval { $content = $route->execute($context) };
    return $app->response_internal_error($@) if $@; # 500

    my $response = Dancer::Core::Response->new(
        content => $content,
        %{ $context->response },
    );
    
    $app->context(undef);
    return $response->to_psgi;
}

sub psgi_app {
    my ($self) = @_;
    sub {
        my ($env) = @_;
        my $request = Dancer::Core::Request->new(env => $env);
        $self->handle_request($request);
    };
}

1;
