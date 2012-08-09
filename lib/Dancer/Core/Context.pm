# ABSTRACT: TODO

package Dancer::Core::Context;
use Moo;
use URI::Escape;

use Dancer::Core::Types;
use Dancer::Core::Request;
use Dancer::Core::Response;
use Dancer::Core::Cookie;

has app => (
    is => 'rw',
    isa => ObjectOf('Dancer::Core::App'),
);

# the PSGI-env to use for building the request to process
# this is the only mandatory argument to a context
has env => (
    is => 'ro',
    required => 1,
    isa => HashRef,
);

# the incoming request 
has request => (
    is => 'rw',
    lazy => 1,
    builder => '_build_request',
    isa => ObjectOf('Dancer::Core::Request'),
);

sub _build_request {
    my ($self) = @_;
    Dancer::Core::Request->new(env => $self->env);
}

# a buffer for per-request variables
has buffer => (
    is => 'rw',
    isa => HashRef,
    default => sub { {} },
);

sub vars { shift->buffer }

sub var {
    my $self = shift;
    @_ == 2
      ? $self->buffer->{$_[0]} = $_[1]
      : $self->buffer->{$_[0]};
}

# a set of changes to apply to the response
# that HashRef will should be passed as attributes to a response object
has response => (
    is => 'rw',
    isa => ObjectOf('Dancer::Core::Response'),
    default => sub { Dancer::Core::Response->new },
);

sub cookies { shift->request->cookies(@_) }

sub cookie {
    my $self = shift;

    return $self->request->cookies->{$_[0]} if @_ == 1;

    # writer
    my ($name, $value, %options) = @_;
    my $c = Dancer::Core::Cookie->new(name => $name, value => $value, %options);
    $self->response->push_header('Set-Cookie' => $c->to_header);
}

sub redirect {
    my ($self, $destination, $status) = @_;

    # RFC 2616 requires an absolute URI with a scheme,
    # turn the URI into that if it needs it

    # Scheme grammar as defined in RFC 2396
    #  scheme = alpha *( alpha | digit | "+" | "-" | "." )
    my $scheme_re = qr{ [a-z][a-z0-9\+\-\.]* }ix;
    if ($destination !~ m{^ $scheme_re : }x) {
        $destination = $self->request->uri_for($destination, {}, 1);
    }

    $self->response->redirect($destination, $status);
}

1;
