# ABSTRACT: Response object for Dancer2

package Dancer2::Core::Response;

use Moo;

use Encode;
use Dancer2::Core::Types;
use Dancer2::Core::MIME;

use Dancer2 ();
use Dancer2::Core::HTTP;

use HTTP::Headers::Fast;
use Scalar::Util qw(blessed);
use Plack::Util;
use Safe::Isa;
use Sub::Quote ();

use overload
  '@{}' => sub { $_[0]->to_psgi },
  '""'  => sub { $_[0] };

has mime_type => (
    'is'      => 'ro',
    'isa'     => InstanceOf['Dancer2::Core::MIME'],
    'default' => sub { Dancer2::Core::MIME->new() },
);

has headers => (
    is     => 'ro',
    isa => InstanceOf['HTTP::Headers'],
    lazy   => 1,
    coerce => sub {
        my ($value) = @_;
        # HTTP::Headers::Fast reports that it isa 'HTTP::Headers',
        # but there is no actual inheritance.
        $value->$_isa('HTTP::Headers')
          ? $value
          : HTTP::Headers::Fast->new(@{$value});
    },
    default => sub {
        HTTP::Headers::Fast->new();
    },
    handles => [qw<header push_header>],
);

sub headers_to_array {
    my $self    = shift;
    my $headers = shift || $self->headers;

    my @hdrs;
    $headers->scan( sub {
        my ( $k, $v ) = @_;
         $v =~ s/\015\012[\040|\011]+/chr(32)/ge; # replace LWS with a single SP
         $v =~ s/\015|\012//g; # remove CR and LF since the char is invalid here
        push @hdrs, $k => $v;
    });

    return \@hdrs;
}

# boolean to tell if the route passes or not
has has_passed => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);

sub pass { shift->has_passed(1) }

has serializer => (
    is  => 'rw',
    isa => ConsumerOf ['Dancer2::Core::Role::Serializer'],
);

has charset => (
    is        => 'rw',
    isa       => Str,
    predicate => 'has_charset',
);

has is_encoded => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);

has is_halted => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);

sub halt {
    my ( $self, $content ) = @_;
    $self->content( $content ) if @_ > 1;
    $self->is_halted(1);
}

has status => (
    is      => 'rw',
    isa     => Num,
    default => sub {200},
    lazy    => 1,
    coerce  => sub { Dancer2::Core::HTTP->status(shift) },
);

has content => (
    is        => 'rw',
    isa       => Str,
    predicate => 'has_content',
    clearer   => 'clear_content',
);

has server_tokens => (
    is      => 'ro',
    isa     => Bool,
    default => sub {1},
);

around content => sub {
    my ( $orig, $self ) = ( shift, shift );

    # called as getter?
    @_ or return $self->$orig;

    # No serializer defined; encode content
    $self->serializer
        or return $self->$orig( $self->encode_content(@_) );

    # serialize content
    my $serialized = $self->serialize(@_);
    $self->is_encoded(1); # All serializers return byte strings
    return $self->$orig( defined $serialized ? $serialized : '' );
};

has default_content_type => (
    is      => 'rw',
    isa     => Str,
    default => sub {'text/html'},
);

sub encode_content {
    my ( $self, $content ) = @_;

    return $content if $self->is_encoded;

    # Apply default content type if none set.
    my $ct = $self->content_type ||
             $self->content_type( $self->default_content_type );

    return $content if $ct !~ /^text/;
    my $charset = $self->headers->content_type_charset;
    $charset = $self->charset
      if !defined $charset && $self->has_charset;
    return $content if !defined $charset || $charset eq '';

    # we don't want to encode an empty string, it will break the output
    $content or return $content;

    $self->content_type("$ct; charset=$charset")
      if $ct !~ /charset/;

    $self->is_encoded(1);
    return Encode::encode( $charset, $content );
}

sub new_from_plack {
    my ($class, $psgi_res) = @_;

    return Dancer2::Core::Response->new(
        status   => $psgi_res->status,
        headers  => $psgi_res->headers,
        content  => $psgi_res->body,
    );
}

sub new_from_array {
    my ($class, $arrayref) = @_;

    return Dancer2::Core::Response->new(
        status    => $arrayref->[0],
        headers   => $arrayref->[1],
        content   => $arrayref->[2][0],
    );
}

sub to_psgi {
    my ($self) = @_;

    my $headers = $self->headers;
    my $status  = $self->status;

    Plack::Util::status_with_no_entity_body($status)
        and return [ $status, $self->headers_to_array($headers), [] ];

    my $content = $self->content;
    # It is possible to have no content and/or no content type set
    # e.g. if all routes 'pass'. Set the default value for the content
    # (an empty string), allowing serializer hooks to be triggered
    # as they may change the content..
    $content = $self->content('') if ! defined $content;

    if ( !$headers->header('Content-Length')    &&
         !$headers->header('Transfer-Encoding') &&
         defined( my $content_length = length $content ) ) {
         $headers->push_header( 'Content-Length' => $content_length );
    }

    # More defaults
    $self->content_type or $self->content_type($self->default_content_type);
    return [ $status, $self->headers_to_array($headers), [ $content ], ];
}

# sugar for accessing the content_type header, with mimetype care
sub content_type {
    my $self = shift;

    if ( scalar @_ > 0 ) {
        my $mimetype = $self->mime_type->name_or_type(shift);
        $self->header( 'Content-Type' => $mimetype );
        return $mimetype;
    }
    else {
        return $self->header('Content-Type');
    }
}

has _forward => (
    is  => 'rw',
    isa => HashRef,
);

sub forward {
    my ( $self, $uri, $params, $opts ) = @_;
    $self->_forward( { to_url => $uri, params => $params, options => $opts } );
}

sub is_forwarded {
    my $self = shift;
    $self->_forward;
}

sub redirect {
    my ( $self, $destination, $status ) = @_;
    $self->status( $status || 302 );

    # we want to stringify the $destination object (URI object)
    $self->header( 'Location' => "$destination" );
}

sub error {
    my $self = shift;

    my $error = Dancer2::Core::Error->new(
        response => $self,
        @_,
    );

    $error->throw;
    return $error;
}

sub serialize {
    my ($self, $content) = @_;

    my $serializer = $self->serializer
        or return;

    $content = $serializer->serialize($content)
        or return;

    $self->content_type( $serializer->content_type );
    return $content;
}

1;

__END__

=method pass

Set has_passed to true.

=method serializer()

Returns the optional serializer object used to deserialize request parameters

=attr is_encoded

Flag to tell if the content has already been encoded.

=attr is_halted

Flag to tell whether or not the response should continue to be processed.

=method halt

Shortcut to halt the current response by setting the is_halted flag.

=attr status

The HTTP status for the response.

=attr content

The content for the response, stored as a string.  If a reference is passed, the
response will try coerce it to a string via double quote interpolation.

=attr default_content_type

Default mime type to use for the response Content-Type header
if nothing was specified

=attr charset

Charset to use when encoding C<text/*> responses. An empty value disables
automatic encoding.

=method encode_content

Encodes the stored content according to the stored L<content_type>.  If the content_type
is not a text format C<^text>, then no encoding will take place.

Internally, it uses the L<is_encoded> flag to make sure that content is not encoded twice.

If it encodes the content, then it will return the encoded content.  In all other
cases it returns C<false>.

=method new_from_plack

Creates a new response object from a L<Plack::Response> object.

=method new_from_array

Creates a new response object from a PSGI arrayref.

=method to_psgi

Converts the response object to a PSGI array.

=method content_type($type)

A little sugar for setting or accessing the content_type of the response, via the headers.

=method redirect ($destination, $status)

Sets a header in this response to give a redirect to $destination, and sets the
status to $status.  If $status is omitted, or false, then it defaults to a status of
302.

=method error( @args )

    $response->error( message => "oops" );

Creates a L<Dancer2::Core::Error> object with the given I<@args> and I<throw()>
it against the response object. Returns the error object.

=method serialize( $content )

    $response->serialize( $content );

Serialize and return $content with the response's serializer.
set content-type accordingly.

=attr headers

The attribute that store the headers in a L<HTTP::Headers::Fast> object.

That attribute coerces from ArrayRef and defaults to an empty L<HTTP::Headers::Fast>
instance.

=method header($name)

Return the value of the given header, if present. If the header has multiple
values, returns the list of values if called in list context, the first one
if in scalar context.

=method push_header

Add the header no matter if it already exists or not.

    $self->push_header( 'X-Wing' => '1' );

It can also be called with multiple values to add many times the same header
with different values:

    $self->push_header( 'X-Wing' => 1, 2, 3 );

=method headers_to_array($headers)

Convert the C<$headers> to a PSGI ArrayRef.

If no C<$headers> are provided, it will use the current response headers.
