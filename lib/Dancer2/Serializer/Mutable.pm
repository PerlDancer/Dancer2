package Dancer2::Serializer::Mutable;
# ABSTRACT: Serialize and deserialize content based on HTTP header

use Moo;
use Carp 'croak';
use Encode;
with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (
    default => 'application/json',      # default content type
    reader  => 'default_content_type',  # accessor for the default
);

# The content type *after* serialization.
sub content_type {
    my $self = shift;
    return $self->_get_content_type(qw<accept content_type>)
        || $self->default_content_type;
}


my $formats = {
    'text/x-yaml'        => 'YAML',
    'text/html'          => 'YAML',
    'text/x-data-dumper' => 'Dumper',
    'text/x-json'        => 'JSON',
    'application/json'   => 'JSON',
};

my $serializer = {
    'YAML'   => {
        to      => sub { Dancer2::Core::DSL::to_yaml(@_)   },
        from    => sub { Dancer2::Core::DSL::from_yaml(@_) },
    },
    'Dumper' => {
        to      => sub { Dancer2::Core::DSL::to_dumper(@_)   },
        from    => sub { Dancer2::Core::DSL::from_dumper(@_) },
    },
    'JSON'   => {
        to      => sub { Dancer2::Core::DSL::to_json(@_)   },
        from    => sub { Dancer2::Core::DSL::from_json(@_) },
    },
};

sub support_content_type {
    my ( $self, $ct ) = @_;

    if ( $ct && grep +( $_ eq $ct ), keys %{$formats} ) {
        return 1;
    }

    return 0;
}

sub serialize {
    my ( $self, $entity ) = @_;

    # Look for valid format in the headers
    my $ct = $self->content_type;

    # Match format with a serializer and return
    exists $formats->{$ct} and return $serializer->{$formats->{$ct}}{'to'}->(
        $self, $entity
    );

    # If none is found then just return the entity without change
    return $entity;
}

sub deserialize {
    my ( $self, $content ) = @_;

    # Look for valid format in the headers
    my $ct = $self->_get_content_type(qw<content_type accept>) || $self->default_content_type;
    exists $formats->{$ct} and return $serializer->{$formats->{$ct}}{'from'}->(
        $self, $content
    );

    return $content;
}

# returns the content type from the appropriate headers
sub _get_content_type {
    my ( $self, @methods ) = @_;
    $self->has_request or return;

    # Search for the first HTTP header variable which
    # specifies supported content.
    for my $method ( @methods ) {
        if ( my $value = $self->request->header($method) ) {
            exists $formats->{$value} and return $value;
        }
    }
}

1;

__END__

=head1 NAME

Dancer2::Serializer::Mutable - Serialize and deserialize content using the appropriate HTTP header
(ported from Dancer)

=head1 SYNOPSIS

    # in config.yml
    serializer: Mutable

    # in the app
    put '/something' => sub {
        # deserialized from request
        my $name = param( 'name' );

        ...

        # will be serialized to the most
        # fitting format
        return { message => "user $name added" };
    };

=head1 DESCRIPTION

This serializer will try find the best (de)serializer for a given request.

For deserialization it will take the first value from the HTTP request headers
in the following list and use the respective Serializer.

=over

=item

The B<content_type> from the request headers

=item

the B<accept> from the request headers

=item

The default is B<application/json>

For deserialization the same HTTP request headers are tried but in the opposite
order.

It is possible to set a different Content-Type for deserialization than the
Accept header for deserialization.

=back

The content-type/serializer mapping that C<Dancer2::Serializer::Mutable>
uses is

    serializer                  | content types
    ----------------------------------------------------------
    Dancer2::Serializer::YAML   | text/x-yaml, text/html
    Dancer2::Serializer::Dumper | text/x-data-dumper
    Dancer2::Serializer::JSON   | text/x-json, application/json

=head2 INTERNAL METHODS

The following methods are used internally by C<Dancer2> and are not made
accessible via the DSL.

=head2 serialize

Serialize a data structure. The format it is serialized to is determined
automatically as described above. It can be one of YAML, Dumper, JSON, defaulting
to JSON if there's no clear preference from the request.

=head2 deserialize

Deserialize the provided serialized data to a data structure.  The type of
serialization format depends on the request's content-type. For now, it can
be one of YAML, Dumper, JSON.

=head2 default_content_type

Returns the default content type for the serializer to use if no other type
can be determined from the request headers.

=head2 content_type

Returns the content-type of the data structure AFTER being serialized.

