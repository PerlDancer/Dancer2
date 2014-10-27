package Dancer2::Core::Role::StandardResponses;
# ABSTRACT: Role to provide commonly used responses

use Moo::Role;

sub response {
    my ( $self, $app, $code, $message ) = @_;
    $app->response->status($code);
    $app->response->header( 'Content-Type', 'text/plain' );
    return $message;
}

sub response_200 {
    my ( $self, $app ) = @_;
    $self->response( $app, 200, 'OK' );
}

sub response_201 {
    my ( $self, $app ) = @_;
    $self->response( $app, 201, 'Created' );
}

sub response_202 {
    my ( $self, $app ) = @_;
    $self->response( $app, 202, 'Accepted' );
}

sub response_204 {
    my ( $self, $app ) = @_;
    $self->response( $app, 204, 'No Content' );
}

sub response_300 {
    my ( $self, $app ) = @_;
    $self->response( $app, 300, 'Multiple Choices' );
}

sub response_304 {
    my ( $self, $app ) = @_;
    $self->response( $app, 304, 'Not Modified' );
}

sub response_400 {
    my ( $self, $app ) = @_;
    $self->response( $app, 400, 'Bad Request' );
}

sub response_401 {
    my ( $self, $app ) = @_;
    $self->response( $app, 401, 'Unauthorized' );
}

sub response_403 {
    my ( $self, $app ) = @_;
    $self->response( $app, 403, 'Forbidden' );
}

sub response_404 {
    my ( $self, $app ) = @_;
    $self->response( $app, 404, 'Not Found' );
}

sub response_405 {
    my ( $self, $app ) = @_;
    $self->response( $app, 405, 'Method Not allowed' );
}

sub response_406 {
    my ( $self, $app ) = @_;
    $self->response( $app, 403, 'Not Acceptable' );
}

sub response_409 {
    my ( $self, $app ) = @_;
    $self->response( $app, 409, 'Conflict' );
}

sub response_410 {
    my ( $self, $app ) = @_;
    $self->response( $app, 410, 'Gone' );
}

sub response_412 {
    my ( $self, $app ) = @_;
    $self->response( $app, 412, 'Precondition Failed' );
}

sub response_415 {
    my ( $self, $app ) = @_;
    $self->response( $app, 415, 'Unsupperted Media Type' );
}

sub response_428 {
    my ( $self, $app ) = @_;
    $self->response( $app, 428, 'Precondition Required' );
}

sub response_500 {
    my ( $self, $app ) = @_;
    $self->response( $app, 500, 'Internal Server Error' );
}

sub response_501 {
    my ( $self, $app ) = @_;
    $self->response( $app, 501, 'Not Implemented' );
}

1;

__END__

=method response

Generic method that produces a response given with a code and a message:

    $self->response( $app, 404, "not found" );

=method response_200

Produces a 200 response "OK"

=method response_201

Produces a 201 response "Created"

=method response_402

Produces a 202 response "Accepted"

=method response_204

Produces a 204 response "No Content"

=method response_300

Produces a 300 response "Multiple Choices"

=method response_304

Produces a 304 response "Not Modified"

=method response_400

Produces a 400 response "Bad Request"

=method response_401

Produces a 401 response "Unauthorized"

=method response_403

Produces a 403 response "Forbidden"

=method response_404

Produces a 404 response "Not Found"

=method response_405

Produces a 405 response "Method Not Allowed"

=method response_406

Produces a 406 response "Not Acceptable"

=method response_409

Produces a 409 response "Conflict"

=method response_410

Produces a 410 response "Gone"

=method response_412

Produces a 412 response "Precondition Faiuled"

=method response_415

Produces a 415 response "Unsupported Media Type"

=method response_428

Produces a 428 response "Precondition Required"

=method response_500

Produces a 500 response "Internal Server Error"

=method response_501

Produces a 501 response "Not Implemented"

=cut
