package Dancer::Core::Role::Serializer;
use Dancer::Moo::Types;

use Moo::Role;
with 'Dancer::Core::Role::Engine';

sub supported_hooks { 
    qw(before_serializer after_serializer)
}

sub type { 'Serializer' }

requires 'serialize';
requires 'deserialize';
requires 'loaded';

around serialize => sub {
    my ($orig, $self) = (shift, shift);
    my ($data) = @_;

    $self->execute_hooks('before_serializer', $data);
    my $serialized = $self->$orig($data);
    $self->execute_hooks('after_serializer', $serialized);

    return $serialized;
};

# attribute vs method?
sub content_type { 'text/plain' }

# most serializer don't have to overload this one
sub support_content_type {
    my ($self, $ct) = @_;
    return unless $ct;

    my @toks = split ';', $ct;
    $ct = lc($toks[0]);
    return $ct eq $self->content_type;
}

1;
