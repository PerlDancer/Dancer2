package Dancer2::Core::Role::SessionFactory;
# ABSTRACT: Role for session factories

use Moo::Role;
with 'Dancer2::Core::Role::Engine';

use Carp 'croak';
use Dancer2::Core::Session;
use Dancer2::Core::Types;
use Digest::SHA 'sha1';
use List::Util 'shuffle';
use MIME::Base64 'encode_base64url';
use Module::Runtime 'require_module';
use Ref::Util qw< is_ref is_arrayref is_hashref >;

sub hook_aliases { +{} }
sub supported_hooks {
    qw/
      engine.session.before_retrieve
      engine.session.after_retrieve

      engine.session.before_create
      engine.session.after_create

      engine.session.before_change_id
      engine.session.after_change_id

      engine.session.before_destroy
      engine.session.after_destroy

      engine.session.before_flush
      engine.session.after_flush
      /;
}

sub _build_type {
    'SessionFactory';
}    # XXX vs 'Session'?  Unused, so I can't tell -- xdg

has log_cb => (
    is      => 'ro',
    isa     => CodeRef,
    default => sub { sub {1} },
);

has cookie_name => (
    is      => 'ro',
    isa     => Str,
    default => sub {'dancer.session'},
);

has cookie_domain => (
    is        => 'ro',
    isa       => Str,
    predicate => 1,
);

has cookie_path => (
    is      => 'ro',
    isa     => Str,
    default => sub {"/"},
);

has cookie_duration => (
    is        => 'ro',
    isa       => Str,
    predicate => 1,
);

has session_duration => (
    is        => 'ro',
    isa       => Num,
    predicate => 1,
);

has is_secure => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);

has is_http_only => (
    is      => 'rw',
    isa     => Bool,
    default => sub {1},
);

sub create {
    my ($self) = @_;

    my %args = ( id => $self->generate_id, );

    $args{expires} = $self->cookie_duration
      if $self->has_cookie_duration;

    my $session = Dancer2::Core::Session->new(%args);

    $self->execute_hook( 'engine.session.before_create', $session );

    # XXX why do we _flush now?  Seems unnecessary -- xdg, 2013-03-03
    eval { $self->_flush( $session->id, $session->data ) };
    croak "Unable to create a new session: $@"
      if $@;

    $self->execute_hook( 'engine.session.after_create', $session );
    return $session;
}

{
    my $COUNTER     = 0;
    my $CPRNG_AVAIL = eval { require_module('Math::Random::ISAAC::XS'); 1; } &&
                      eval { require_module('Crypt::URandom'); 1; };

    # don't initialize until generate_id is called so the ISAAC algorithm
    # is seeded after any pre-forking
    my $CPRNG;

    # prepend epoch seconds so session ID is roughly monotonic
    sub generate_id {
        my ($self) = @_;

        if ($CPRNG_AVAIL) {
            $CPRNG ||= Math::Random::ISAAC::XS->new(
                map { unpack( "N", Crypt::URandom::urandom(4) ) } 1 .. 256 );

            # include $$ to ensure $CPRNG wasn't forked by accident
            return encode_base64url(
                pack(
                    "N6",
                    time,          $$,            $CPRNG->irand,
                    $CPRNG->irand, $CPRNG->irand, $CPRNG->irand
                )
            );
        }
        else {
            my $seed = (
                rand(1_000_000_000)   # a random number
                  . __FILE__          # the absolute path as a secret key
                  . $COUNTER++        # impossible to have two consecutive dups
                  . $$         # the process ID as another private constant
                  . "$self"    # the instance's memory address for more entropy
                  . join( '', shuffle( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 ) )

                  # a shuffled list of 62 chars, another random component
            );
            return encode_base64url( pack( "Na*", time, sha1($seed) ) );
        }

    }
}

sub validate_id {
    my ($self, $id) = @_;
    return $id =~ m/^[A-Za-z0-9_\-~]+$/;
}

requires '_retrieve';

sub retrieve {
    my ( $self, %params ) = @_;
    my $id = $params{id};

    $self->execute_hook( 'engine.session.before_retrieve', $id );

    my $data;
    # validate format of session id before attempt to retrieve
    my $rc = eval {
        $self->validate_id($id) && ( $data = $self->_retrieve($id) );
    };
    croak "Unable to retrieve session with id '$id'"
      if ! $rc;

    my %args = ( id => $id, );

    $args{data} = $data
      if $data and is_hashref($data);

    $args{expires} = $self->cookie_duration
      if $self->has_cookie_duration;

    my $session = Dancer2::Core::Session->new(%args);

    $self->execute_hook( 'engine.session.after_retrieve', $session );
    return $session;
}

# XXX eventually we could perhaps require '_change_id'?

sub change_id {
    my ( $self, %params ) = @_;
    my $session = $params{session};
    my $old_id  = $session->id;

    $self->execute_hook( 'engine.session.before_change_id', $old_id );

    my $new_id = $self->generate_id;
    $session->id( $new_id );

    eval { $self->_change_id( $old_id, $new_id ) };
    croak "Unable to change session id for session with id $old_id: $@"
      if $@;

    $self->execute_hook( 'engine.session.after_change_id', $new_id );
}

requires '_destroy';

sub destroy {
    my ( $self, %params ) = @_;
    my $id = $params{id};
    $self->execute_hook( 'engine.session.before_destroy', $id );

    eval { $self->_destroy($id) };
    croak "Unable to destroy session with id '$id': $@"
      if $@;

    $self->execute_hook( 'engine.session.after_destroy', $id );
    return $id;
}

requires '_flush';

sub flush {
    my ( $self, %params ) = @_;
    my $session = $params{session};
    $self->execute_hook( 'engine.session.before_flush', $session );

    eval { $self->_flush( $session->id, $session->data ) };
    croak "Unable to flush session: $@"
      if $@;

    $self->execute_hook( 'engine.session.after_flush', $session );
    return $session->id;
}

sub set_cookie_header {
    my ( $self, %params ) = @_;
    $params{response}->push_header(
        'Set-Cookie',
        $self->cookie( session => $params{session} )->to_header
    );
}

sub cookie {
    my ( $self, %params ) = @_;
    my $session = $params{session};
    croak "cookie() requires a valid 'session' parameter"
      unless is_ref($session) && $session->isa("Dancer2::Core::Session");

    my %cookie = (
        value     => $session->id,
        name      => $self->cookie_name,
        path      => $self->cookie_path,
        secure    => $self->is_secure,
        http_only => $self->is_http_only,
    );

    $cookie{domain} = $self->cookie_domain
      if $self->has_cookie_domain;

    if ( my $expires = $session->expires ) {
        $cookie{expires} = $expires;
    }

    return Dancer2::Core::Cookie->new(%cookie);
}

requires '_sessions';

sub sessions {
    my ($self) = @_;
    my $sessions = $self->_sessions;

    croak "_sessions() should return an array ref"
      unless is_arrayref($sessions);

    return $sessions;
}

1;

__END__

=head1 DESCRIPTION

Any class that consumes this role will be able to store, create, retrieve and
destroy session objects.

The default values for attributes can be overridden in your Dancer2
configuration. See L<Dancer2::Config/Session-engine>.

=attr cookie_name

The name of the cookie to create for storing the session key

Defaults to C<dancer.session>

=attr cookie_domain

The domain of the cookie to create for storing the session key.
Defaults to the empty string and is unused as a result.

=attr cookie_path

The path of the cookie to create for storing the session key.
Defaults to "/".

=attr cookie_duration

Default duration before session cookie expiration.  If set, the
L<Dancer2::Core::Session> C<expires> attribute will be set to the current time
plus this duration (expression parsed by L<Dancer2::Core::Time>).

=attr session_duration

Duration in seconds before sessions should expire, regardless of cookie
expiration.  If set, then SessionFactories should use this to enforce a limit
on session validity.

=attr is_secure

Boolean flag to tell if the session cookie is secure or not.

Default is false.

=attr is_http_only

Boolean flag to tell if the session cookie is http only.

Default is true.

=head1 INTERFACE

Following is the interface provided by this role. When specified the required
methods to implement are described.

=cut

=head2 create

Create a brand new session object and store it. Returns the newly created
session object.

Triggers an exception if the session is unable to be created.

    my $session = MySessionFactory->create();

This method does not need to be implemented in the class.

=head2 generate_id

Returns a randomly-generated, guaranteed-unique string.
By default, it is a 32-character, URL-safe, Base64 encoded combination
of a 32 bit timestamp and a 160 bit SHA1 digest of random seed data.
The timestamp ensures that session IDs are generally monotonic.

The default algorithm is not guaranteed cryptographically secure, but it's
still reasonably strong for general use.

If you have installed L<Math::Random::ISAAC::XS> and L<Crypt::URandom>,
the seed data will be generated from a cryptographically-strong
random number generator.

This method is used internally by create() to set the session ID.

This method does not need to be implemented in the class unless an
alternative method for session ID generation is desired.

=head2 validate_id

Returns true if a session id is of the correct format, or false otherwise.

By default, this ensures that the session ID is a string of characters
from the Base64 schema for "URL Applications" plus the C<~> character.

This method does not need to be implemented in the class unless an
alternative set of characters for session IDs is desired.

=head2 retrieve

Return the session object corresponding to the session ID given. If none is
found, triggers an exception.

    my $session = MySessionFactory->retrieve(id => $id);

The method C<_retrieve> must be implemented.  It must take C<$id> as a single
argument and must return a hash reference of session data.

=head2 change_id

Changes the session ID of the corresponding session.
    
    MySessionFactory->change_id(session => $session_object);

The method C<_change_id> must be implemented. It must take C<$old_id> and
C<$new_id> as arguments and change the ID from the old one to the new one
in the underlying session storage.

=head2 destroy

Purges the session object that matches the ID given. Returns the ID of the
destroyed session if succeeded, triggers an exception otherwise.

    MySessionFactory->destroy(id => $id);

The C<_destroy> method must be implemented. It must take C<$id> as a single
argument and destroy the underlying data.

=head2 flush

Make sure the session object is stored in the factory's backend. This method is
called to notify the backend about the change in the session object.

The Dancer application will not call flush unless the session C<is_dirty>
attribute is true to avoid unnecessary writes to the database when no
data has been modified.

An exception is triggered if the session is unable to be updated in the backend.

    MySessionFactory->flush(session => $session);

The C<_flush> method must be implemented.  It must take two arguments: the C<$id>
and a hash reference of session data.

=head2 set_cookie_header

Sets the session cookie into the response object

    MySessionFactory->set_cookie_header(
        response  => $response,
        session   => $session,
        destroyed => undef,
    );

The C<response> parameter contains a L<Dancer2::Core::Response> object.
The C<session> parameter contains a L<Dancer2::Core::Session> object.

The C<destroyed> parameter is optional.  If true, it indicates the
session was marked destroyed by the request context.  The default
C<set_cookie_header> method doesn't need that information, but it is
included in case a SessionFactory must handle destroyed sessions
differently (such as signalling to middleware).

=head2 cookie

Coerce a session object into a L<Dancer2::Core::Cookie> object.

    MySessionFactory->cookie(session => $session);

=head2 sessions

Return a list of all session IDs stored in the backend.
Useful to create cleaning scripts, in conjunction with session's creation time.

The C<_sessions> method must be implemented.  It must return an array reference
of session IDs (or an empty array reference).

=head1 CONFIGURATION

If there are configuration values specific to your session factory in your config.yml or
environment, those will be passed to the constructor of the session factory automatically.
In order to accept and store them, you need to define accessors for them.

    engines:
      session:
        Example:
          database_connection: "some_data"

In your session factory:

    package Dancer2::Session::Example;
    use Moo;
    with "Dancer2::Core::Role::SessionFactory";

    has database_connection => ( is => "ro" );

You need to do this for every configuration key. The ones that do not have accessors
defined will just go to the void.

=cut
