package Dancer2::Serializer::Mutable;
# ABSTRACT: Serialize and deserialize content based on HTTP header

use Moo;
use Carp 'croak';
use Encode;
use Module::Runtime 'require_module';
with 'Dancer2::Core::Role::Serializer';

use constant DEFAULT_CONTENT_TYPE => 'application/json';

has '+content_type' => ( default => DEFAULT_CONTENT_TYPE() );

my $serializer = {
    'YAML'   => {
        to      => sub { Dancer2::Core::DSL::to_yaml(@_)   },
        from    => sub { Dancer2::Core::DSL::from_yaml(@_) },
    },
    'JSON'   => {
        to      => sub { Dancer2::Core::DSL::to_json(@_)   },
        from    => sub { Dancer2::Core::DSL::from_json(@_) },
    },
};

has enable_dumper => (
    is      => 'ro',
    lazy    => 1,
    default => sub { $_[0]->config->{enable_dumper} || 0 },
);

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

                if ( $s eq 'Dumper' && !$self->enable_dumper ) {
                    croak
                        "The Dumper serializer is disabled. Set "
                        . "engines.serializer.Mutable.enable_dumper to a "
                        . "true value to use it. This requires the "
                        . "Dancer2::Serializer::Dumper distribution to be "
                        . "installed.";
                }

                $self->_load_serializer($s);
            }

            return $mapping;
        }

        my %default_mapping = (
            'text/x-yaml'      => 'YAML',
            'text/html'        => 'YAML',
            'text/x-json'      => 'JSON',
            'application/json' => 'JSON',
        );

        if ( $self->enable_dumper ) {
            $default_mapping{'text/x-data-dumper'} = 'Dumper';
            $self->_load_serializer('Dumper');
        }

        return \%default_mapping;
    },
);

sub _load_serializer {
    my ( $self, $name ) = @_;

    return $serializer->{$name} if $serializer->{$name};

    my $serializer_class = "Dancer2::Serializer::$name";
    require_module($serializer_class);
    my $serializer_object = $serializer_class->new;
    return $serializer->{$name} = {
        from => sub { shift; $serializer_object->deserialize(@_) },
        to   => sub { shift; $serializer_object->serialize(@_)   },
    };
}

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
                # A header value may carry parameters after the content
                # type itself (e.g. 'text/x-yaml; charset=utf-8'). Strip
                # anything from the first ';' onward, trim surrounding
                # whitespace and lowercase what's left, so the lookup
                # matches on the content type alone - the mapping's keys
                # are bare lowercase content types. (An Accept header
                # listing several comma-separated types is not split
                # further here: the whole remainder is matched as one
                # string, so only a single-type Accept is recognised.)
                ( my $type = $value ) =~ s/;.*$//;
                $type =~ s/^\s+|\s+$//g;
                $type = lc $type;
                if ( my $serializer = $self->mapping->{$type} ) {
                    $self->set_content_type($type);
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
For this, it will pick the first valid content type found from a list, and
use its related serializer. The list, and its order, is not the same in both
directions:

=over

=item

When B<deserializing> an incoming request body (that is, working out how to
read it), the order is: the B<content_type> from the request headers, then
the B<accept> from the request headers, then the default of
B<application/json>.

=item

When B<serializing> a response (that is, working out what to send back), the
order is: the B<accept> from the request headers, then the B<content_type>
from the request headers, then the default of B<application/json>. Consulting
C<Accept> first is deliberate - it is the header a client uses to say what it
wants back, which need not match the content type of what it sent.

=back

In both directions, a header's value is matched against the mapping on its
content type alone: any C<;>-separated parameters (such as
C<; charset=utf-8>) are stripped, surrounding whitespace is trimmed, and the
result is lowercased before comparison. So C<Content-Type: text/x-yaml>,
C<Content-Type: text/x-yaml; charset=utf-8> and C<Content-Type: TEXT/X-YAML>
are all recognised as C<text/x-yaml>. An C<Accept> header listing several
comma-separated types is not split further - it is matched as a whole after
parameter-stripping, so only a single-type C<Accept> value is recognised;
anything else falls through to the next header or the default.

The content-type/serializer mapping that C<Dancer2::Serializer::Mutable>
uses is

    serializer                  | content types
    ----------------------------------------------------------
    Dancer2::Serializer::YAML   | text/x-yaml, text/html
    Dancer2::Serializer::JSON   | text/x-json, application/json

The keys above are bare, lowercase content types - not raw header values - as
described above.

A different mapping can be provided via the config file. For example,
the default mapping would be configured as

    engines:
        serializer:
            Mutable:
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-json'        : JSON
                    'application/json'   : JSON

The values are the serializers to use. Serialization for C<YAML> and C<JSON>
are done using internal Dancer mechanisms. Any other serializer will be taken
to be a Dancer2 serialization class (minus the C<Dancer2::Serializer::>
prefix) and an instance of it will be used to serialize/deserialize data.
For example, adding L<Dancer2::Serializer::XML> to the mapping would be:

    engines:
        serializer:
            Mutable:
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-json'        : JSON
                    'text/xml'           : XML

=head2 Dumper

The Dumper serializer is B<not> available by default, as it deserializes
request content by evaluating it as Perl code, which is insecure and a bad
idea. If you really want to use it, you must explicitly opt in, and you must
have the C<Dancer2-Serializer-Dumper> distribution installed. You can then
enable it either by adding it to your mapping and setting
C<enable_dumper>:

    engines:
        serializer:
            Mutable:
                enable_dumper: 1
                mapping:
                    'text/x-yaml'        : YAML
                    'text/html'          : YAML
                    'text/x-data-dumper' : Dumper
                    'text/x-json'        : JSON
                    'application/json'   : JSON

or by using the default mapping with C<enable_dumper> set, which adds
C<text/x-data-dumper> to the default mapping:

    engines:
        serializer:
            Mutable:
                enable_dumper: 1

Attempting to use the Dumper serializer without setting C<enable_dumper>
to a true value will cause a fatal error.

=head2 INTERNAL METHODS

The following methods are used internally by C<Dancer2> and are not made
accessible via the DSL.

=head2 serialize

Serialize a data structure. The format it is serialized to is determined
automatically as described above. It can be one of YAML, JSON, defaulting
to JSON if there's no clear preference from the request.

=head2 deserialize

Deserialize the provided serialized data to a data structure.  The type of
serialization format depends on the request's content-type. For now, it can
be one of YAML, JSON.

=head2 content_type

Returns the content-type that was used during the last C<serialize> /
C<deserialize> call. B<WARNING> : you must call C<serialize> / C<deserialize>
before calling C<content_type>. Otherwise the return value will be C<undef>.
