package Dancer2::Core::Role::StandardResponses;
# ABSTRACT: Role to provide commonly used responses
$Dancer2::Core::Role::StandardResponses::VERSION = '0.159002';
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

=encoding UTF-8

=head1 NAME

Dancer2::Core::Role::StandardResponses - Role to provide commonly used responses

=head1 VERSION

version 0.159002

=head1 METHODS

=head2 response

Generic method that produces a custom response given with a code and a message:

    $self->response( $app, 404, 'Not Found' );

This could be used to create your own, which is separate from the standard one:

    $self->response( $app, 404, 'File missing in action' );

=head2 standard_response

Produces a standard response using the code.

    # first example can be more easily written as
    $self->standard_response( $app, 404 );

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
