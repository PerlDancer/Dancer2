package Dancer2::Core::Role::Serializer;
# ABSTRACT: Role for Serializer engines

use Moo::Role;
use Try::Tiny;
use Dancer2::Core::Types;

with 'Dancer2::Core::Role::Engine';

sub supported_hooks {
    qw(
      engine.serializer.before
      engine.serializer.after
    );
}

sub _build_type {'Serializer'}

requires 'serialize';
requires 'deserialize';

has logger => (
    is        => 'ro',
    isa       => MaybeConsumerOf['Dancer2::Core::Role::Logger'],
    handles   => ['log'],
    predicate => 'has_logger',
);

has content_type => (
    is       => 'ro',
    isa      => Str,
    required => 1,
    writer   => 'set_content_type'
);

around serialize => sub {
    my ( $orig, $self, $content, $options ) = @_;

    $self->execute_hook( 'engine.serializer.before', $content );

    my $data = try {
        $self->$orig($content, $options);
    } catch {
        $self->log( core => "Failed to serialize the request: $_" );
    };

    $data and $self->execute_hook( 'engine.serializer.after', $data );

    return $data;
};

around deserialize => sub {
    my ( $orig, $self, $content, $options ) = @_;

    my $data = try {
        $self->$orig($content, $options);
    } catch {
        $self->log( core => "Failed to deserialize the request: $_" );
    };

    return $data;
};

# most serializer don't have to overload this one
sub support_content_type {
    my ( $self, $ct ) = @_;
    return unless $ct;

    my @toks = split ';', $ct;
    $ct = lc( $toks[0] );
    return $ct eq $self->content_type;
}

1;

__END__

=head1 DESCRIPTION

Any class that consumes this role will be able to be used as a
serializer under Dancer2.

In order to implement this role, the consumer B<must> implement the
methods C<serialize> and C<deserialize>, and should define
the C<content_type> attribute value.

=head1 METHODS

=attr content_type

The I<content type> of the object after being serialized. For example,
a JSON serializer would have a I<application/json> content type
defined.

=method serialize($content, [\%options])

The serialize method need to be implemented by the consumer. It
receives the serializer class object and a reference to the object to
be serialized. Should return the object after being serialized, in the
content type defined by the C<content_type> attribute.

A third optional argument is a hash reference of options to the
serializer.

The serialize method must return bytes and therefore has to handle any
encoding.

=method deserialize($content, [\%options])

The inverse method of C<serialize>. Receives the serializer class
object and a string that should be deserialized. The method should
return a reference to the deserialized Perl data structure.

A third optional argument is a hash reference of options to the
serializer.

The deserialize method receives encoded bytes and must therefore
handle any decoding required.

