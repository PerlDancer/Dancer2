# ABSTRACT: Role to provide commonly used responses

package Dancer2::Core::Role::StandardResponses;
use Moo::Role;

=method response

Generic method that produces a response in the context given with a code and a
message:

    $self->response( $ctx, 404, "not found" );

=cut

sub response {
    my ( $self, $ctx, $code, $message ) = @_;
    $ctx->response->status($code);
    $ctx->response->header( 'Content-Type', 'text/plain' );
    return $message;
}

=method response_400

Produces a 400 response in the context given.

=cut

sub response_400 {
    my ( $self, $ctx ) = @_;
    $self->response( $ctx, 400, 'Bad Request' );
}

=method response_404

Produces a 404 response in the context given.

=cut

sub response_404 {
    my ( $self, $ctx ) = @_;
    $self->response( $ctx, 404, 'Not Found' );
}

=method response_403

Produces a 403 response in the context given.

=cut

sub response_403 {
    my ( $self, $ctx ) = @_;
    $self->response( $ctx, 403, 'Unauthorized' );
}

1;
