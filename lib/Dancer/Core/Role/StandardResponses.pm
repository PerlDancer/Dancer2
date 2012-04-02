# ABSTRACT: TODO

package Dancer::Core::Role::StandardResponses;
use Moo::Role;

sub response {
    my ($self, $ctx, $code, $message) = @_;
    $ctx->response->status($code);
    $ctx->response->header('Content-Type', 'text/plain');
    return $message;
}

sub response_400 {
    my ($self, $ctx) = @_;
    $self->response($ctx, 400, 'Bad Request');
}

sub response_404 {
    my ($self, $ctx) = @_;
    $self->response($ctx, 404, 'Not Found');
}

sub response_403 {
    my ($self, $ctx) = @_;
    $self->response($ctx, 403, 'Unauthorized');
}

1;
