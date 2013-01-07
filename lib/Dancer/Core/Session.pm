package Dancer::Core::Session;
#ABSTRACT: class to represent any session object

=head1 DESCRIPTION

A session object encapsulates anything related to a specific session: its ID,
its data, and its expiration.

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

=attr data

Contains the data of the session (Hash).

=cut

has data => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=attr expires

Number of seconds for the expiry of the session cookie. Don't add the current
timestamp to it, will be done automatically.

Default is no expiry (session cookie will leave for the whole browser's
session).

For a lifetime of one hour:

  expires => 3600

=cut

has expires => (
    is => 'rw',
    isa => Str,
    coerce => sub {
        my $value = shift;
        $value += time;
    },
);

=attr factory

The SessionFactory object that created this session object. Required.

=cut

has factory => (
    is        => 'ro',
    isa       => sub {
        die "factory must be a SessionFactory"
            unless $_[0]->DOES("Dancer::Core::Role::SessionFactory")
    },
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

Returns C<$value>.

=cut

sub write {
    my ($self, $key, $value) = @_;
    $self->data->{$key} = $value;
}

=method delete

Deletes a key from session data

  $session->delete('something');

Returns the value deleted from the session.

=cut

sub delete {
    my ($self, $key, $value) = @_;
    delete $self->data->{$key};
}

=method destroy

Destroys the session.  Deletes data in the session object and instructs
the C<factory> to destroy the session as well.  Also sets expiration time
into the past.

=cut

sub destroy {
    my ($self) = @_;
    $self->factory->destroy( id => $self->id );
    %{$self->data} = ();
    $self->expires( -86400 );
    return;
}

1;
