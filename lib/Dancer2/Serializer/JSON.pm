package Dancer2::Serializer::JSON;
# ABSTRACT: Serializer for handling JSON data

use Moo;
use Ref::Util qw< is_arrayref is_hashref >;
use JSON::MaybeXS ();
use Encode qw(decode FB_CROAK);
use Scalar::Util 'blessed';

with 'Dancer2::Core::Role::Serializer';

has '+content_type' => ( default => sub {'application/json'} );

# helpers
sub from_json { __PACKAGE__->deserialize(@_) }

sub to_json { __PACKAGE__->serialize(@_) }

sub decode_json {
    my ( $entity ) = @_;

    JSON::MaybeXS::decode_json($entity);
}

sub encode_json {
    my ( $entity ) = @_;

    JSON::MaybeXS::encode_json(_ensure_characters($entity));
}

# class definition
sub serialize {
    my ( $self, $entity, $options ) = @_;

    my $config = blessed $self ? $self->config : {};
    my $strict_utf8 = $config->{strict_utf8};
    $options ||= {};

    foreach (keys %$config) {
        $options->{$_} = $config->{$_} unless exists $options->{$_};
    }

    $options->{utf8} = 1;
    exists $options->{strict_utf8}
        and $strict_utf8 = delete $options->{strict_utf8};
    $entity = _ensure_characters( $entity, $strict_utf8, $self );
    JSON::MaybeXS->new($options)->encode($entity);
}

sub deserialize {
    my ( $self, $entity, $options ) = @_;

    $options ||= {};
    $options->{utf8} = 1;
    delete $options->{strict_utf8};
    JSON::MaybeXS->new($options)->decode($entity);
}

my $HAS_UNICODE_UTF8 = eval { require Unicode::UTF8; 1; };

sub _valid_utf8 {
    my ($bytes) = @_;
    return Unicode::UTF8::valid_utf8($bytes) if $HAS_UNICODE_UTF8;
    return eval { decode( 'UTF-8', $bytes, FB_CROAK ); 1 };
}

sub _decode_utf8 {
    my ($bytes) = @_;
    return Unicode::UTF8::decode_utf8($bytes) if $HAS_UNICODE_UTF8;
    return decode( 'UTF-8', $bytes );
}

sub _ensure_characters {
    my ( $entity, $strict_utf8, $self ) = @_;

    return $entity if !defined $entity;
    return _ensure_scalar( $entity, $strict_utf8, $self ) if !ref $entity;

    if ( is_arrayref($entity) ) {
        for my $i ( 0 .. $#{$entity} ) {
            $entity->[$i] = _ensure_characters( $entity->[$i], $strict_utf8, $self );
        }
        return $entity;
    }

    if ( is_hashref($entity) ) {
        for my $key ( keys %{$entity} ) {
            my $value = $entity->{$key};
            my $decoded_key = _ensure_scalar( $key, $strict_utf8, $self );
            my $decoded_value =
              _ensure_characters( $value, $strict_utf8, $self );

            if ( $decoded_key ne $key ) {
                delete $entity->{$key};
                $entity->{$decoded_key} = $decoded_value;
            } else {
                $entity->{$key} = $decoded_value;
            }
        }
        return $entity;
    }

    return $entity;
}

sub _ensure_scalar {
    my ( $value, $strict_utf8, $self ) = @_;

    return $value if utf8::is_utf8($value);
    return $value if $value !~ /[\x80-\xFF]/;
    return _decode_utf8($value) if _valid_utf8($value);

    _invalid_utf8( $strict_utf8, $self );
    return $value;
}

sub _invalid_utf8 {
    my ( $strict_utf8, $self ) = @_;
    my $msg = 'Invalid UTF-8 in JSON data';

    $strict_utf8
        and die "$msg\n";

    if ( blessed($self) ) {
        $self->log_cb->( warning => "$msg; leaving bytes unchanged" );
    } else {
        warn "$msg; leaving bytes unchanged\n";
    }
}

1;

__END__

=head1 DESCRIPTION

This is a serializer engine that allows you to turn Perl data structures into
JSON output and vice-versa.

=head1 METHODS

=attr content_type

Returns 'application/json'

=func from_json($content, \%options)

This is an helper available to transform a JSON data structure to a Perl data structures.

=func to_json($content, \%options)

This is an helper available to transform a Perl data structure to JSON.

Calling this function will B<not> trigger the serialization's hooks.

=method serialize($content)

Serializes a Perl data structure into a JSON string.

=method deserialize($content)

Deserializes a JSON string into a Perl data structure.



=head2 Configuring the JSON Serializer using C<set engines>

The JSON serializer options can be configured via C<set engines>. The most
common settings are:

=over 4

=item   allow_nonref

Ignore non-ref scalars returned from handlers. With this set the "Hello, World!"
handler returning a string will be dealt with properly.

=item   strict_utf8

If true, invalid UTF-8 bytes in data passed to the JSON encoder will cause an
error. If false (default), invalid bytes are left as-is and a warning is logged.

=back

Note: the C<utf8> option is forced to true internally to ensure JSON output
is UTF-8 encoded bytes.

Set engines should be called prior to setting JSON as the serializer:

 set engines =>
 {
     serializer =>
     {
         JSON =>
         {
            allow_nonref => 1
         },
     }
 };

 set serializer      => 'JSON';
 set content_type    => 'application/json';

=head2 Returning non-JSON data.

Handlers can return non-JSON via C<send_as>, which overrides the default serializer:

 get '/' =>
 sub
 {
     send_as html =>
     q{Welcome to the root of all evil...<br>step into my office.}
 };

Any other non-JSON returned format supported by 'send_as' can be used.
