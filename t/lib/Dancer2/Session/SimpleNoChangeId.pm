package Dancer2::Session::SimpleNoChangeId;
# ABSTRACT: in-memory session backend for Dancer2
#
# This is a version of Dancer2::Session::Simple that does not support
# _change_id thus using stash data/destroy/reload session

use Moo;
use Dancer2::Core::Types;
use Carp;

with 'Dancer2::Core::Role::SessionFactory';

# The singleton that contains all the session objects created
my $SESSIONS = {};

sub _sessions {
    my ($self) = @_;
    return [ keys %{$SESSIONS} ];
}

sub _retrieve {
    my ( $class, $id ) = @_;
    my $s = $SESSIONS->{$id};

    croak "Invalid session ID: $id"
      if !defined $s;

    return $s;
}

sub _destroy {
    my ( $class, $id ) = @_;
    delete $SESSIONS->{$id};
}

sub _flush {
    my ( $class, $id, $data ) = @_;
    $SESSIONS->{$id} = $data;
}

1;
