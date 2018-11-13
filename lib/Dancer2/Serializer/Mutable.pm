package Dancer2::Serializer::Mutable;
# ABSTRACT: Serialize and deserialize content based on HTTP header

use Moo;
use Carp 'croak';
use Encode;
with 'Dancer2::Core::Role::Serializer';

use constant DEFAULT_CONTENT_TYPE => 'application/json';

has '+content_type' => ( default => DEFAULT_CONTENT_TYPE() );

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

has mapping => (
    is   => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        if ( my $mapping = $self->config->{mapping} ) {

            # initialize non-default serializers
            for my $s ( values %$mapping ) {
                # TODO allow for arguments via the config
                next if $serializer->{$s};
                my $serializer_object = ('Dancer2::Serializer::'.$s)->new;
                $serializer->{$s} = {
                    from => sub { shift; $serializer_object->deserialize(@_) },
                    to   => sub { shift; $serializer_object->serialize(@_)   },
                };
            }

            return $mapping;
        }


        return {
            'text/x-yaml'        => 'YAML',
            'text/html'          => 'YAML',
            'text/x-data-dumper' => 'Dumper',
            'text/x-json'        => 'JSON',
            'application/json'   => 'JSON',
        }
    },
);

sub serialize {
    my ( $self, $entity ) = @_;

    # Look for valid format in the headers
    my $format = $self->_get_content_type('accept');

    # Match format with a serializer and return
    $format and return $serializer->{$format}{'to'}->(
        $self, $entity
    );

    # If none is found then just return the entity without change
    return $entity;
}

sub deserialize {
    my ( $self, $content ) = @_;

    my $format = $self->_get_content_type('content_type');
    $format and return $serializer->{$format}{'from'}->($self, $content);

    return $content;
}

sub _get_content_type {
    my ($self, $header) = @_;

    if ( $self->has_request ) {
        # Search for the first HTTP header variable which specifies
        # supported content. Both content_type and accept are checked
        # for backwards compatibility.
        foreach my $method ( $header, qw<content_type accept> ) {
            if ( my $value = $self->request->header($method) ) {
                if ( my $serializer = $self->mapping->{$value} ) {
                    $self->set_content_type($value);
                    return $serializer;
                }
            }
        }
    }

    # If none if found, return the default, 'JSON'.
    $self->set_content_type( DEFAULT_CONTENT_TYPE() );
    return 'JSON';
}

1;

__END__

=head1 SYNOPSIS

    # in config.yml
    serializer: Mutable

    engines:
        serializer:
            Mutable:
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-data-dumper' : Dumper
                    'text/x-json'        : JSON
                    'application/json'   : JSON

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

The default is B<application/json>

=back

The content-type/serializer mapping that C<Dancer2::Serializer::Mutable>
uses is

    serializer                  | content types
    ----------------------------------------------------------
    Dancer2::Serializer::YAML   | text/x-yaml, text/html
    Dancer2::Serializer::Dumper | text/x-data-dumper
    Dancer2::Serializer::JSON   | text/x-json, application/json

A different mapping can be provided via the config file. For example,
the default mapping would be configured as

    engines:
        serializer:
            Mutable:
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-data-dumper' : Dumper
                    'text/x-json'        : JSON
                    'application/json'   : JSON

The keys of the mapping are the content-types to serialize,
and the values the serializers to use. Serialization for C<YAML>, C<Dumper>
and C<JSON> are done using internal Dancer mechanisms. Any other serializer will
be taken to be as Dancer2 serialization class (minus the C<Dancer2::Serializer::> prefix)
and an instance of it will be used
to serialize/deserialize data. For example, adding L<Dancer2::Serializer::XML>
to the mapping would be:

    engines:
        serializer:
            Mutable:
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-data-dumper' : Dumper
                    'text/x-json'        : JSON
                    'text/xml'           : XML

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
