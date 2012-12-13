package Dancer::Core::Session;
#ABSTRACT: class to represent any session object

=head1 DESCRIPTION

A session object encapsulates anything related to a specific session: it's ID,
its data, creation timestampe...

It is completely agnostic of how it will be stored, this is the role of
a factory that consumes L<Dancer::Core::Role::SessionFactory> to know about that.

Generally, session objects should not be created directly.  The correct way to
get a new session object is to call the C<create()> method on a session engine
that implements the SessionFactory role.  This is done automatically by the
context object if a session engine is defined.

=cut

use strict;
use warnings;
use Moo;
use Dancer::Core::Types;


=attr id

The identifier of the session object. Required. By default,
L<Dancer::Core::Role::SessionFactory> sets this to a randomly-generated,
guaranteed-unique string.

=cut

has id => (
    is        => 'rw',
    isa       => Str,
    required  => 1,
);

=method read

Reader on the session data

    my $value = $session->read('something');

Returns C<undef> if the key does not exist in the session.

=cut

sub read {
    my ($self, $key) = @_;
    return $self->data->{$key};
}


=method write

Writer on the session data

  $session->write('something', $value);

If C<$value> is undefined, the key is deleted from the session.
Returns C<$value>.

=cut

sub write {
    my ($self, $key, $value) = @_;
    if ( defined $value ) {
        $self->data->{$key} = $value;
    }
    else {
        delete $self->data->{$key};
    }
    return $value;
}

=attr is_secure 

Boolean flag to tell if the session cookie is secure or not.

Default is false.

=cut

has is_secure => (
    is => 'rw',
    isa => Bool,
    default => sub { 0 },
);

=attr is_http_only

Boolean flag to tell if the session cookie is http only.

Default is true.

=cut

has is_http_only => (
    is => 'rw',
    isa => Bool,
    default => sub { 1 },
);


=attr expires

Timestamp for the expiry of the session cookie.

Default is no expiry (session cookie will leave for the whole browser's
session).

=cut

has expires => (
    is => 'rw',
    isa => Str,
);


=attr data

Contains the data of the session (Hash).

=cut

has data => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=attr creation_time

A timestamp of the moment when the session was created.

=cut

has creation_time => (
    is => 'ro',
    default => sub { time() },
);

=method cookie

Coerce the session object into a L<Dancer::Core::Cookie> object.

=cut

sub cookie {
    my ($self) = @_;

    my %cookie = (
        name      => 'dancer.session',
        value     => $self->id,
        secure    => $self->is_secure,
        http_only => $self->is_http_only,
    );

    if (my $expires = $self->expires) {
        $cookie{expires} = $expires;
    }

    return Dancer::Core::Cookie->new(%cookie);
}


1;
