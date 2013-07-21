# ABSTRACT: A cookie representing class

package Dancer2::Core::Cookie;
use Moo;
use URI::Escape;
use Dancer2::Core::Types;
use Dancer2::Core::Time;
use Carp 'croak';
use overload '""' => \&_get_value;

=head1 SYNOPSIS

    use Dancer2::Core::Cookie;

    my $cookie = Dancer2::Core::Cookie->new(
        name => $cookie_name, value => $cookie_value
    );

    my $value = $cookie->value;

    print "$cookie"; # objects stringify to their value.

=head1 DESCRIPTION

Dancer2::Cookie provides a HTTP cookie object to work with cookies.

=method my $cookie=new Dancer2::Cookie (%opts);

Create a new Dancer2::Core::Cookie object.

You can set any attribute described in the I<ATTRIBUTES> section above.

=method my $header=$cookie->to_header();

Creates a proper HTTP cookie header from the content.

=cut

sub to_header {
    my $self   = shift;
    my $header = '';

    my $value = join( '&', map { uri_escape($_) } $self->value );
    my $no_httponly = defined( $self->http_only ) && $self->http_only == 0;

    my @headers = $self->name . '=' . $value;
    push @headers, "path=" . $self->path       if $self->path;
    push @headers, "expires=" . $self->expires if $self->expires;
    push @headers, "domain=" . $self->domain   if $self->domain;
    push @headers, "Secure"                    if $self->secure;
    push @headers, 'HttpOnly' unless $no_httponly;

    return join '; ', @headers;
}


=attr value

The cookie's value.

(Note that cookie objects use overloading to stringify to their value, so if 
you say e.g. return "Hi, $cookie", you'll get the cookie's value there.)

In list context, returns a list of potentially multiple values; in scalar
context, returns just the first value.  (So, if you expect a cookie to have
multiple values, use list context.)

=cut 

has value => (
    is       => 'rw',
    isa      => ArrayRef,
    required => 0,
    coerce   => sub {
        my $value = shift;
        my @values =
            ref $value eq 'ARRAY' ? @$value
          : ref $value eq 'HASH'  ? %$value
          :                         ($value);
        return [@values];
    },
);

around value => sub {
    my $orig  = shift;
    my $self  = shift;
    my $array = $orig->( $self, @_ );
    return wantarray ? @$array : $array->[0];
};

# this is only for overloading; need a real sub to refer to, as the Moose
# attribute accessor won't be available at that point.
sub _get_value { shift->value }


=attr name

The cookie's name.

=cut

has name => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);


=attr expires

The cookie's expiration date.  There are several formats.

Unix epoch time like 1288817656 to mean "Wed, 03-Nov-2010 20:54:16 GMT"

It also supports a human readable offset from the current time such as "2 hours". 
See the documentation of L<Dancer2::Core::Time> for details of all supported
formats.

=cut

has expires => (
    is       => 'rw',
    isa      => Str,
    required => 0,
    coerce   => sub {
        Dancer2::Core::Time->new( expression => $_[0] )->gmt_string;
    },
);


=attr domain

The cookie's domain.

=cut

has domain => (
    is       => 'rw',
    isa      => Str,
    required => 0,
);

=attr path

The cookie's path.

=cut

has path => (
    is        => 'rw',
    isa       => Str,
    default   => sub {'/'},
    predicate => 1,
);

=attr secure

If true, it instructs the client to only serve the cookie over secure
connections such as https.

=cut

has secure => (
    is       => 'rw',
    isa      => Bool,
    required => 0,
    default  => sub {0},
);

=attr http_only

By default, cookies are created with a property, named C<HttpOnly>,
that can be used for security, forcing the cookie to be used only by
the server (via HTTP) and not by any JavaScript code.

If your cookie is meant to be used by some JavaScript code, set this
attribute to 0.

=cut

has http_only => (
    is       => 'rw',
    isa      => Bool,
    required => 0,
    default  => sub {0},
);

1;
