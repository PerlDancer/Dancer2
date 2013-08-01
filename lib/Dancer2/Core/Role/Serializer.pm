# ABSTRACT: Role for Serializer engines

package Dancer2::Core::Role::Serializer;
use Dancer2::Core::Types;

use Moo::Role;
with 'Dancer2::Core::Role::Engine';

sub supported_hooks {
    qw(
      engine.serializer.before
      engine.serializer.after
    );
}

sub _build_type {'Serializer'}

=head1 REQUIREMENTS

Classes that consume that role must implement the following methods
C<serialize>, C<deserialize> and C<loaded>.

=cut

requires 'serialize';
requires 'deserialize';
requires 'loaded';

has error => (
    is        => 'rw',
    isa       => Str,
    predicate => 1,
);

around serialize => sub {
    my ( $orig, $self, @data ) = @_;
    $self->execute_hook( 'engine.serializer.before', @data );
    my $serialized = eval {$self->$orig(@data);};

    if ($@) {
        $self->error($@);
    }else{
        $self->execute_hook( 'engine.serializer.after', $serialized );
    }
    return $serialized;
};

around deserialize => sub {
    my ( $orig, $self, @data ) = @_;
    my $data = eval { $self->$orig(@data); };
    $self->error($@) if $@;
    return $data;
};

# attribute vs method?
sub content_type {'text/plain'}

# most serializer don't have to overload this one
sub support_content_type {
    my ( $self, $ct ) = @_;
    return unless $ct;

    my @toks = split ';', $ct;
    $ct = lc( $toks[0] );
    return $ct eq $self->content_type;
}

1;
