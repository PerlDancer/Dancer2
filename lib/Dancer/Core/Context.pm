package Dancer::Core::Context;
use Moo;
use Dancer::Moo::Types;
use URI::Escape;

use Dancer::Core::Request;
use Dancer::Core::Response;
use Dancer::Core::Cookie;

# the PSGI-env to use for building the request to process
# this is the only mandatory argument to a context
has env => (
    is => 'ro',
    required => 1,
    isa => sub { Dancer::Moo::Types::HashRef(@_) } ,
);

# the incoming request 
has request => (
    is => 'rw',
    lazy => 1,
    builder => '_build_request',
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Request' => @_) },
);

sub _build_request {
    my ($self) = @_;
    Dancer::Core::Request->new(env => $self->env);
}

# a buffer for per-request variables
has buffer => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef(@_) },
    default => sub { {} },
);

# a set of changes to apply to the response
# that HashRef will should be passed as attributes to a response object
has response => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Response', @_) },
    default => sub { Dancer::Core::Response->new },
);

has cookies => (
    is => 'rw',
    isa => sub { HashRef(@_) },
    lazy => 1,
    builder => '_build_cookies',
);

sub _build_cookies {
    my ($self) = @_;

    my $env_str = $self->env->{COOKIE} || $self->env->{HTTP_COOKIE};
    return {} unless defined $env_str;

    my $cookies = {};
    foreach my $cookie ( split( /[,;]\s/, $env_str ) ) {
        # here, we don't want more than the 2 first elements
        # a cookie string can contains something like:
        # cookie_name="foo=bar"
        # we want `cookie_name' as the value and `foo=bar' as the value
        my( $name,$value ) = split(/\s*=\s*/, $cookie, 2);
        my @values;
        if ( $value ne '' ) {
            @values = map { uri_unescape($_) } split( /[&;]/, $value );
        }
        $cookies->{$name} =
          Dancer::Core::Cookie->new( name => $name, value => \@values );
    }
    return $cookies;
}

1;
