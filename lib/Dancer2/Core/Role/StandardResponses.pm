package Dancer2::Core::Role::StandardResponses;
# ABSTRACT: Role to provide commonly used responses

use Moo::Role;
use Dancer2::Core::HTTP;

sub response {
    my ( $self, $app, $code, $message ) = @_;
    $app->response->status($code);
    $app->response->header( 'Content-Type', 'text/plain' );
    return $message;
}

sub standard_response {
    my ( $self, $app, $status_code ) = @_;

    return $self->response(
        $app,
        $status_code,
        Dancer2::Core::HTTP->status_message($status_code),
    );
}

1;

__END__

=pod

=method response

Generic method that produces a custom response given with a code and a message:

    $self->response( $app, 404, 'Not Found' );

This could be used to create your own, which is separate from the standard one:

    $self->response( $app, 404, 'File missing in action' );

=method standard_response

Produces a standard response using the code.

    # first example can be more easily written as
    $self->standard_response( $app, 404 );

