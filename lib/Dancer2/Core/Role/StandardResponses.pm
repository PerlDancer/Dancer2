package Dancer2::Core::Role::StandardResponses;
# ABSTRACT: Role to provide commonly used responses

use Moo::Role;

sub response {
    my ( $self, $app, $code, $message ) = @_;
    $app->response->status($code);
    $app->response->header( 'Content-Type', 'text/plain' );
    return $message;
}

sub response_400 {
    my ( $self, $app ) = @_;
    $self->response( $app, 400, 'Bad Request' );
}

sub response_404 {
    my ( $self, $app ) = @_;
    $self->response( $app, 404, 'Not Found' );
}

sub response_403 {
    my ( $self, $app ) = @_;
    $self->response( $app, 403, 'Unauthorized' );
}

1;

__END__

=method response

Generic method that produces a response given with a code and a message:

    $self->response( $app, 404, "not found" );

=method response_400

Produces a 400 response

=method response_404

Produces a 404 response

=method response_403

Produces a 403 response

=cut
