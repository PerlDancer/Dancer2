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

=cut

sub read {
    my ($self, $key) = @_;
    return $self->data->{$key};
}


=method write

Writer on the session data

=cut

sub write {
    my ($self, $key, $value) = @_;
    $self->data->{$key} = $value;
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

=attr cookie_name 

The name of the cookie to create for storing the session key

Defaults to C<dancer.session>

=cut

has cookie_name => (
    is => 'ro',
    isa => Str,
    default => sub { 'dancer.session' },
);

=method cookie

Coerce the session object into a L<Dancer::Core::Cookie> object.

=cut

sub cookie {
    my ($self) = @_;

    my %cookie = (
        name      => $self->cookie_name,
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
