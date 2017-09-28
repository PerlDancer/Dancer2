package Dancer2::Serializer::Mutable;

# ABSTRACT: Serialize and deserialize content based on HTTP header

use Moo;
use Carp 'croak';
use Encode;

# TODO this is a workaround because Serializer::YAML
#      requires YAML.pm only during ->new()
use YAML ();

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => (
    default => 1,    # to satify 'required' flag of attribute
);

my %content_types = (
    Dumper => ['text/x-data-dumper'],
    JSON   => ['application/json', 'text/x-json'],
    YAML   => ['text/x-yaml'],
);

our %formats;
while (my ($format => $content_types) = each %content_types) {
    $formats{$_} = $format for @$content_types;
}

my %serializers = (
    YAML => {
        to   => sub { Dancer2::Core::DSL::to_yaml(@_) },
        from => sub { Dancer2::Core::DSL::from_yaml(@_) },
    },
    Dumper => {
        to   => sub { Dancer2::Core::DSL::to_dumper(@_) },
        from => sub { Dancer2::Core::DSL::from_dumper(@_) },
    },
    JSON => {
        to   => sub { Dancer2::Core::DSL::to_json(@_) },
        from => sub { Dancer2::Core::DSL::from_json(@_) },
    },
);

sub deserialize {
    my ($self, $content) = @_;

    my $content_type = $self->_best_content_type(qw< Content-Type Accept >)
      or return;

    my $format      = $formats{$content_type};
    my $deserialize = $serializers{$format}{from};

    return $deserialize->($self, $content);
}

sub serialize {
    my ($self, $entity) = @_;

    if (ref $entity ne 'ARRAY' and ref $entity ne 'HASH') {
        $self->set_content_type('text/html');
        return $entity;
    }

    my $content_type = $self->_best_content_type(qw< Accept Content-Type >)
      || 'application/json';

    my $format    = $formats{$content_type};
    my $serialize = $serializers{$format}{to};

    $self->set_content_type($content_type);
    return $serialize->($self, $entity);
}

sub support_content_type {
    my ($self, $content_type) = @_;

    defined $content_type
      or return;

    $content_type =~ s/;.+$//;    # remove e.g. '; charset=utf8'

    return exists $formats{$content_type} ? $content_type : '';
}

sub _best_content_type {
    my $self = shift;

    for my $header (@_) {
        my (@values) = $self->request->header($header) || next;

        if ($header eq 'Accept') {
            @values = split /,\s*/, $values[0];
        }

        for my $value (@values) {
            my $content_type = $self->support_content_type($value);

            $content_type and return $content_type;
        }

        return;    # header found but no value is supported
    }

    return;        # no header found
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
