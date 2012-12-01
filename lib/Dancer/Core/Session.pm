package Dancer::Core::Session;
#ABSTRACT: class to represent aany session object

=head1 DESCRIPTION

A session object encapsulates anything related to a specific session: it's ID,
its data, creation timestampe...

It is completely agnostic of how it will be stored, this is the role of
a factory that consumes L<Dancer::Core::Role::SessionFactory> to know about that.

=cut

use strict;
use warnings;
use Moo;
use Dancer::Core::Types;
use Digest::SHA1 'sha1_hex';
use List::Util 'shuffle';


=attr id

The identifier of the session object. Randomnly generated, guaranteed to be
unique.

=cut

has id => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    builder => '_build_id',
);

my $COUNTER = 0;

sub _build_id {
    my ($self) = @_;

    my $seed = rand(1_000_000_000) # a random number
             . __FILE__            # the absolute path as a secret key
             . $COUNTER++          # impossible to have two consecutive dups
             . "$self"             # the memory address of the object
             . time()              # impossible to have dups between seconds
             . $$                  # the process ID as another private constant
             . join('', 
                shuffle('a'..'z', 
                       'A'..'Z', 
                        0 .. 9))   # a shuffled list of 62 chars, another random component
             ;

    return sha1_hex($seed);
}


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
