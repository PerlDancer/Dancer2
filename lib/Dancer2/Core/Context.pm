package Dancer2::Core::Context;

# ABSTRACT: handles everything proper to a request's context.

use Moo;
use URI::Escape;
use Carp 'croak';

use Dancer2::Core::Types;
use Dancer2::Core::Request;
use Dancer2::Core::Response;
use Dancer2::Core::Cookie;

=attr app

Reference to the L<Dancer2::Core::App> object for the current application.

=cut


has app => (
    is        => 'rw',
    isa       => InstanceOf ['Dancer2::Core::App'],
    weak_ref  => 1,
    predicate => 1,
);


=attr request

A L<Dancer2::Core::Request> object, built from the PSGI environment variable for this request.

=cut

# the incoming request
has request => (
    is      => 'rw',
    isa     => InstanceOf ['Dancer2::Core::Request'],
    lazy    => 1,
);

# a buffer for per-request variables
has buffer => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

=method vars

Returns a hashref of all per-request variables stored in this object.

=cut

sub vars { shift->buffer }

=method var

By-name interface to variables stored in this context object.

  my $stored = $context->var('some_variable');

returns the value of 'some_variable', while

  $context->var('some_variable' => 'value');

will set it.

=cut

sub var {
    my $self = shift;
    @_ == 2
      ? $self->buffer->{ $_[0] } = $_[1]
      : $self->buffer->{ $_[0] };
}

=attr response

A L<Dancer2::Core::Response> object, used to set content, headers and HTTP status codes.

=cut

# a set of changes to apply to the response
# that HashRef will should be passed as attributes to a response object
has response => (
    is      => 'rw',
    isa     => InstanceOf ['Dancer2::Core::Response'],
    lazy    => 1,
    default => sub {
        my $self = shift;

        my $engine = $self->has_app
            ? $self->app->engine('serializer')
            : undef;

        return Dancer2::Core::Response->new(
            $engine ? (serializer => $engine) : ()
        );
    },
);

=method cookies

Shortcut that dispatches to L<Dancer2::Core::Request>'s cookies method.

=cut

sub cookies { shift->request->cookies(@_) }

=method cookie

Get a cookie from the L<request> object, or set one in the L<response> object.

=cut

sub cookie {
    my $self = shift;

    return $self->request->cookies->{ $_[0] } if @_ == 1;

    # writer
    my ( $name, $value, %options ) = @_;
    my $c =
      Dancer2::Core::Cookie->new( name => $name, value => $value, %options );
    $self->response->push_header( 'Set-Cookie' => $c->to_header );
}

=method redirect($destination, $status)

Sets a redirect in the response object.  If $destination is not an absolute URI, then it will
be made into an absolute URI, relative to the URI in the request.

=cut

sub redirect {
    my ( $self, $destination, $status ) = @_;

    # RFC 2616 requires an absolute URI with a scheme,
    # turn the URI into that if it needs it

    # Scheme grammar as defined in RFC 2396
    #  scheme = alpha *( alpha | digit | "+" | "-" | "." )
    my $scheme_re = qr{ [a-z][a-z0-9\+\-\.]* }ix;
    if ( $destination !~ m{^ $scheme_re : }x ) {
        $destination = $self->request->uri_for( $destination, {}, 1 );
    }

    $self->response->redirect( $destination, $status );
    # Short circuit any remaining before hook / route code
    # ('pass' and after hooks are still processed)
    $self->with_return->($self->response) if $self->has_with_return;
}

=method halt

Flag the response object as 'halted'.

If called during request dispatch, immediatly returns the response
to the dispatcher and after hooks will not be run.

=cut

sub halt {
   my ($self) = @_;
   $self->response->halt;
   # Short citcuit any remaining hook/route code
   $self->with_return->($self->response) if $self->has_with_return;
}

=method pass

Flag the response object as 'passed'.

If called during request dispatch, immediatly returns the response
to the dispatcher.

=cut

sub pass {
   my ($self) = @_;
   $self->response->pass;
   # Short citcuit any remaining hook/route code
   $self->with_return->($self->response) if $self->has_with_return;
}

=attr session

Handle for the current session object, if any

=cut

has session => (
    is        => 'rw',
    isa       => Session,
    lazy      => 1,
    builder   => '_build_session',
    predicate => '_has_session',
    clearer   => 1,
);

sub _build_session {
    my ($self) = @_;
    my $session;

    # Find the session engine
    my $engine = $self->app->engine('session');

    # find the session cookie if any
    if ( !$self->destroyed_session ) {
        my $session_id;
        my $session_cookie = $self->cookie( $engine->cookie_name );
        if ( defined $session_cookie ) {
            $session_id = $session_cookie->value;
        }

        # if we have a session cookie, try to retrieve the session
        if ( defined $session_id ) {
            eval { $session = $engine->retrieve( id => $session_id ) };
            croak "Fail to retrieve session: $@"
              if $@ && $@ !~ /Unable to retrieve session/;
        }
    }

    # create the session if none retrieved
    return $session ||= $engine->create();
}

=method has_session

Returns true if session engine has been defined and if either a session object
has been instantiated in the context or if a session cookie was found and not
subsequently invalidated.

=cut

sub has_session {
    my ($self) = @_;

    my $engine = $self->app->engine('session');

    return $self->_has_session
      || ( $self->cookie( $engine->cookie_name )
        && !$self->has_destroyed_session );
}

=attr destroyed_session

We cache a destroyed session here; once this is set we must not attempt to
retrieve the session from the cookie in the request.  If no new session is
created, this is set (with expiration) as a cookie to force the browser to
expire the cookie.

=cut

has destroyed_session => (
    is        => 'rw',
    isa       => InstanceOf ['Dancer2::Core::Session'],
    predicate => 1,
);

=method destroy_session

Destroys the current session and ensures any subsequent session is created
from scratch and not from the request session cookie

=cut

sub destroy_session {
    my ($self) = @_;

    # Find the session engine
    my $engine = $self->app->engine('session');

    # Expire session, set the expired cookie and destroy the session
    # Setting the cookie ensures client gets an expired cookie unless
    # a new session is created and supercedes it
    my $session = $self->session;
    $session->expires(-86400);    # yesterday
    $engine->destroy( id => $session->id );

    # Clear session in context and invalidate session cookie in request
    $self->destroyed_session($session);
    $self->clear_session;

    return;
}


=attr with_return

Used to cache the coderef from L<Return::MultiLevel> within the dispatcher.

=cut

has with_return => (
    is        => 'rw',
    predicate => 1,
    clearer   => 'clear_with_response',
);

1;
