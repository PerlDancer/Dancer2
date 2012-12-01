package Dancer::Core::Role::SessionFactory;
#ABSTRACT: Role for session factories

=head1 DESCRIPTION

Any class that consumes this role will be able to store, create, retrieve and
destroy session objects.

=cut

use strict;
use warnings;
use Carp 'croak';
use Dancer::Core::Session;
use Dancer::Core::Types;

use Moo::Role;
with 'Dancer::Core::Role::Engine';
sub _build_type {'Session'}
sub supported_hooks { }

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

=cut

sub create {
    my ($class) = @_;
    my $session = Dancer::Core::Session->new();

    eval { $class->_flush($session) };
    croak "Unable to create a new session: $@" 
      if $@;

    return $session;
}

=head2 retrieve

Return the session object corresponding to the session ID given. If none is
found, triggers an exception.

    my $session = MySessionFactory->retrieve(id => $id);

The method C<_retrieve> must be implemented.

=cut

requires '_retrieve';

sub retrieve {
    my ($class, %params) = @_;
    my $session;
    my $id = $params{id};

    eval { $session = $class->_retrieve($id) };
    croak "Unable to retrieve session with id '$id'"
      if $@;

    return $session;
}

=head2 destroy

Purges the session object that matches the ID given. Returns the ID of the
destroyed session if succeeded, triggers an exception otherwise.

    MySessionFactory->destroy(id => $id);

The C<_destroy> method must be implemented.

=cut

requires '_destroy';

sub destroy {
    my ($class, %params) = @_;
    my $id = $params{id};

    eval { $class->_destroy($id) };
    croak "Unable to destroy session with id '$id': $@"
      if $@;

    return $id;
}

=head2 flush

Make sure the session object is stored in the factory's backend. This method is
called to notify the backend about the change in the session object.

An exception is triggered if the session is unable to be updated in the backend.

    MySessionFactory->flush(session => $session);

The C<_flush> method must be implemented.

=cut

requires '_flush';

sub flush {
    my ($class, %params) = @_;
    my $session = $params{session};

    eval { $class->_flush($session) };
    croak "Unable to flush session: $@"
      if $@;

    return $session->id;
}


=method sessions

Return a list of all session IDs stored in the backend.
Useful to create cleaning scripts, in conjunction with session's creation time.

Required method : C<_sessions>

=cut

requires '_sessions';

sub sessions {
    my ($self) = @_;
    my $sessions = $self->_sessions;

    croak "_sessions() should return an array ref"
      if ref($sessions) ne ref([]);

    return $sessions;
}

1;
