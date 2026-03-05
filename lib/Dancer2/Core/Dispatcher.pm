package Dancer2::Core::Dispatcher;
# ABSTRACT: Class for dispatching request to the appropriate route handler

use Moo;

use Dancer2::Core::Types;
use Dancer2::Core::Request;
use Dancer2::Core::Response;

has apps => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has apps_psgi => (
    is      => 'ro',
    isa     => ArrayRef,
    lazy    => 1,
    builder => '_build_apps_psgi',
);

sub _build_apps_psgi {
    my $self = shift;
    return [ map +( $_->name, $_->to_app ), @{ $self->apps } ];
}

sub dispatch {
    my ( $self, $env ) = @_;
    my @apps = @{ $self->apps_psgi };

    DISPATCH: while (1) {
        for ( my $i = 0; $i < @apps; $i += 2 ) {
            my ( $app_name, $app ) = @apps[ $i, $i + 1 ];

            my $response = $app->($env);

            # check for an internal request
            delete Dancer2->runner->{'internal_forward'}
                and next DISPATCH;

            # the app raised a flag saying it couldn't match anything
            # which is different than "I matched and it's a 404"
            delete Dancer2->runner->{'internal_404'}
                or do {
                    delete Dancer2->runner->{'internal_request'};
                    return $response;
                };
        }

        # don't run anymore
        delete Dancer2->runner->{'internal_request'};
        last;
    } # while

    # a 404 on all apps, using the first app
    my $default_app = $self->apps->[0];
    my $request     = $default_app->build_request($env);
    return $default_app->response_not_found($request)->to_psgi;
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
    $dispatcher->response_internal_error($app, $error);

    # Capture response not found for an application the after dispatch
    $dispatcher->response_not_found($env);

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
object and an env as input arguments.

C<dispatch> returns a response object of L<Dancer2::Core::Response>.

Any before hook and matched route code is wrapped to allow DSL keywords such
as forward and redirect to short-circuit remaining code, returning across
multiple stack frames without having to throw an exception.

=head2 response_internal_error

The C<response_internal_error> takes as input the list of applications and
a variable error and returns an object of L<Dancer2::Core::Error>.

=head2 response_not_found

The C<response_not_found> consumes as input the list of applications and an
object of type L<Dancer2::Core::App> and returns an object
L<Dancer2::Core::Error>.
