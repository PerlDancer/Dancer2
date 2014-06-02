package Dancer2::Serializer::Mutable;
# ABSTRACT: Serialize and deserialize content using the appropriate module
# based on the HTTP header variables

use Moo;
use Carp 'croak';
use Encode;
with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (default => 'application/json');     # We need a default here

# helpers
my $formats = {
    'text/x-yaml'           => 'YAML',
    'text/html'             => 'YAML',
    'text/x-data-dumper'    => 'Dumper',
    'text/x-json'           => 'JSON',
    'application/json'      => 'JSON',
};

my $serializer = {
    'YAML'   => {
        to      => sub { return Dancer2::Core::DSL::to_yaml(@_); },
        from    => sub { return Dancer2::Core::DSL::from_yaml(@_); },
    },
    'Dumper' => {
        to      => sub { return Dancer2::Core::DSL::to_dumper(@_); },
        from    => sub { return Dancer2::Core::DSL::from_dumper(@_); },
    },
    'JSON'   => {
        to      => sub { return Dancer2::Core::DSL::to_json(@_); },
        from    => sub { return Dancer2::Core::DSL::from_json(@_); },
    },
};

# class definition
sub loaded {1}

sub support_content_type {
    my ($self, $ct) = @_;
    if($ct && grep /^$ct$/, keys %$formats) {
        $self->set_content_type($ct);
        return 1;
    };

    return 0;
}

sub serialize {
    my ($self, $entity) = @_;

    # Look for valid format in the headers
    # Match format with a serializer and return
    # If none is found then just undef
    my $format = $self->_get_content_type();
    $format and return $serializer->{$format}{to}->( $self->context, $entity );

    return $entity;

}

sub deserialize {
    my ($self, $content) = @_;

    # The right content type should already be set
    my $format = $formats->{$self->content_type};
    $format and return $serializer->{$format}{from}->( $self, $content );

    return $content;
}

sub _request {
    my $self = shift;
    return $self->context ? $self->context->request : undef;
}

sub _get_content_type {
    my $self = shift;

    # Search for the first HTTP header variable which
    # specifies supported content.
    # If none if found, return undef.
    my $request = $self->_request;
    return unless defined $request;

    foreach my $method ( qw<content_type accept accept_type> ) {
        if ( my $value = $request->$method ) {
            if( exists $formats->{$value} ) {
                $self->set_content_type($value);
                return $formats->{$value};
            }
        }
    }

    return;
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
For this, it will pick the first valid content type found from the following list
and use its related serializer.

=over

=item

The B<content_type> from the request headers

=item

the B<accept> from the request headers

=item

the B<accept_type> from the request headers

=item

The default is B<application/json>

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

=head2 content_type

Returns the content-type that was used during the last C<serialize> /
C<deserialize> call. B<WARNING> : you must call C<serialize> / C<deserialize>
before calling C<content_type>. Otherwise the return value will be C<undef>.
