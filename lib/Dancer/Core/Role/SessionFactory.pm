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
use Digest::SHA1 'sha1_hex';
use List::Util 'shuffle';

use Moo::Role;
with 'Dancer::Core::Role::Engine';

sub supported_hooks {
   qw/
    engine.session.before_retrieve
    engine.session.after_retrieve

    engine.session.before_create
    engine.session.after_create

    engine.session.before_destroy
    engine.session.after_destroy

    engine.session.before_flush
    engine.session.after_flush
   /
}

sub _build_type {'Session'}

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
    my ($self) = @_;
    my $session = Dancer::Core::Session->new( id => $self->generate_id );
    $self->execute_hook('engine.session.before_create', $session);

    eval { $self->_flush($session) };
    croak "Unable to create a new session: $@" 
      if $@;

    $self->execute_hook('engine.session.after_create', $session);
    return $session;
}

=head2 generate_id

Returns a randomly-generated, guaranteed-unique string.  (It is not
guaranteed cryptographically secure, but it's still reasonably
strong for general use.)  This method is used internally by create()
to set the session ID.

This method does not need to be implemented in the class unless an
alternative method for session ID generation is desired.

=cut

{
    my $COUNTER = 0;

    sub generate_id {
        my ($self) = @_;

        my $seed = rand(1_000_000_000) # a random number
                . __FILE__            # the absolute path as a secret key
                . $COUNTER++          # impossible to have two consecutive dups
                . time()              # impossible to have dups between seconds
                . $$                  # the process ID as another private constant
                . "$self"             # the instance's memory address for more entropy
                . join('',
                    shuffle('a'..'z',
                          'A'..'Z',
                            0 .. 9))   # a shuffled list of 62 chars, another random component
                ;

        return sha1_hex($seed);
    }
}


=head2 retrieve

Return the session object corresponding to the session ID given. If none is
found, triggers an exception.

    my $session = MySessionFactory->retrieve(id => $id);

The method C<_retrieve> must be implemented.

=cut

requires '_retrieve';

sub retrieve {
    my ($self, %params) = @_;
    my $session;
    my $id = $params{id};

    $self->execute_hook('engine.session.before_retrieve', $id);

    eval { $session = $self->_retrieve($id) };
    croak "Unable to retrieve session with id '$id'"
      if $@;

    $self->execute_hook('engine.session.after_retrieve', $session);
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
    my ($self, %params) = @_;
    my $id = $params{id};
    $self->execute_hook('engine.session.before_destroy', $id);

    eval { $self->_destroy($id) };
    croak "Unable to destroy session with id '$id': $@"
      if $@;

    $self->execute_hook('engine.session.after_destroy', $id);
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
    my ($self, %params) = @_;
    my $session = $params{session};
    $self->execute_hook('engine.session.before_flush', $session);

    eval { $self->_flush($session) };
    croak "Unable to flush session: $@"
      if $@;

    $self->execute_hook('engine.session.after_flush', $session);
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
