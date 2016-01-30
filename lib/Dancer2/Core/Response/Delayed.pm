package Dancer2::Core::Response::Delayed;
# ABSTRACT: Delayed responses

use Moo;
use Dancer2::Core::Types qw<CodeRef InstanceOf>;

has request => (
    is       => 'ro',
    isa      => InstanceOf['Dancer2::Core::Request'],
    required => 1,
);

has response => (
    is       => 'ro',
    isa      => InstanceOf['Dancer2::Core::Response'],
    required => 1,
    handles => [qw/status headers/],
);

has cb => (
    is       => 'ro',
    isa      => CodeRef,
    required => 1,
);

has error_cb => (
    is        => 'ro',
    isa       => CodeRef,
    predicate => '_has_error_cb',
);

sub is_halted()  {0}
sub has_passed() {0}

sub to_psgi {
    my $self = shift;

    return sub {
        my $responder = shift;

        local $Dancer2::Core::Route::REQUEST       = $self->request;
        local $Dancer2::Core::Route::RESPONSE      = $self->response;
        local $Dancer2::Core::Route::RESPONDER     = $responder;
        local $Dancer2::Core::Route::WRITER;

        local $Dancer2::Core::Route::ERROR_HANDLER =
            $self->_has_error_cb ? $self->error_cb : undef;

        $self->cb->();
    };
}

1;

__END__

=pod

=head1 SYNOPSIS

    my $response = Dancer2::Core::Response::Delayed->new(
        request   => Dancer2::Core::Request->new(...),
        response  => Dancer2::Core::Response->new(...),
        cb        => sub {...},

        # optional error handling
        error_cb  => sub {
            my ($error) = @_;
            ...
        },
    );

    # or in an app
    get '/' => sub {
        # delayed response:
        delayed {
            # streaming content
            content "data";
            content "more data";

            # close user connection
            done;
        } on_error => sub {
            my ($error) = @_;
            warning 'Failed to stream to user: ' . request->remote_address;
        };
    };

=head1 DESCRIPTION

This object represents a delayed (asynchronous) response for L<Dancer2>.
It can be used via the C<delayed> keyword.

It keeps references to a request and a response in order to avoid
keeping a reference ot the application.

=head1 ATTRIBUTES

=head2 request

Contains a request the delayed response uses.

In the context of a web request, this will be the request that existed
when the delayed response has been created.

=head2 response

Contains a response the delayed response uses.

In the context of a web request, this will be the response that existed
when the delayed response has been created.

=head2 cb

The code that will be run asynchronously.

=head2 error_cb

A callback for handling errors. This callback receives the error as its
first (and currently only) parameter.

=head1 METHODS

=head2 is_halted

A method indicating whether the response has halted.

This is useless in the context of an asynchronous request so it simply
returns no.

This method is likely going away.

=head2 has_passed

A method indicating whether the response asked to skip the current
response.

This is useless in the context of an asynchronous request so it simply
returns no.

This method is likely going away.

=head2 to_psgi

Create a PSGI response. The way it works is by returning a proper PSGI
response subroutine which localizes the request and response (in case
the callback wants to edit them without a reference to them), and then
calls the callback.

Finally, when the callback is done, it asks the response (whether it
was changed or not) to create its own PSGI response (calling C<to_psgi>)
and sends that to the callback it receives as a delayed response.
