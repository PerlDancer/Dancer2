package Dancer2::Core::Session;
# ABSTRACT: class to represent any session object
$Dancer2::Core::Session::VERSION = '0.159002';
use Moo;
use Dancer2::Core::Types;
use Dancer2::Core::Time;

has id => (
    # for some specific plugins this should be rw.
    # refer to https://github.com/PerlDancer/Dancer2/issues/460
    is       => 'rw',
    isa      => Str,
    required => 1,
);

has data => (
    is      => 'ro',
    lazy    => 1,
    default => sub { {} },
);

has expires => (
    is     => 'rw',
    isa    => Str,
    coerce => sub {
        my $value = shift;
        $value += time if $value =~ /^[\-\+]?\d+$/;
        Dancer2::Core::Time->new( expression => $value )->epoch;
    },
);

has is_dirty => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);


sub read {
    my ( $self, $key ) = @_;
    return $self->data->{$key};
}


sub write {
    my ( $self, $key, $value ) = @_;
    $self->is_dirty(1);
    $self->data->{$key} = $value;
}

sub delete {
    my ( $self, $key, $value ) = @_;
    $self->is_dirty(1);
    delete $self->data->{$key};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer2::Core::Session - class to represent any session object

=head1 VERSION

version 0.159002

=head1 DESCRIPTION

A session object encapsulates anything related to a specific session: its ID,
its data, and its expiration.

It is completely agnostic of how it will be stored, this is the role of
a factory that consumes L<Dancer2::Core::Role::SessionFactory> to know about that.

Generally, session objects should not be created directly.  The correct way to
get a new session object is to call the C<create()> method on a session engine
that implements the SessionFactory role.  This is done automatically by the
app object if a session engine is defined.

=head1 ATTRIBUTES

=head2 id

The identifier of the session object. Required. By default,
L<Dancer2::Core::Role::SessionFactory> sets this to a randomly-generated,
guaranteed-unique string.

This attribute can be modified if your Session implementation requires this.

=head2 data

Contains the data of the session (Hash).

=head2 expires

Number of seconds for the expiry of the session cookie. Don't add the current
timestamp to it, will be done automatically.

Default is no expiry (session cookie will leave for the whole browser's
session).

For a lifetime of one hour:

  expires => 3600

=head2 is_dirty

Boolean value for whether data in the session has been modified.

=head1 METHODS

=head2 read

Reader on the session data

    my $value = $session->read('something');

Returns C<undef> if the key does not exist in the session.

=head2 write

Writer on the session data

  $session->write('something', $value);

Sets C<is_dirty> to true. Returns C<$value>.

=head2 delete

Deletes a key from session data

  $session->delete('something');

Sets C<is_dirty> to true. Returns the value deleted from the session.

=head1 AUTHOR

Dancer Core Developers

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Alexis Sukrieh.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
