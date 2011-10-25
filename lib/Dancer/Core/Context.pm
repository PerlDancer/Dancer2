package Dancer::Core::Context;
use Moo;
use Dancer::Moo::Types;
use URI::Escape;

use Dancer::Core::Request;
use Dancer::Core::Response;
use Dancer::Core::Cookie;

has app => (
    is => 'ro',
    isa => sub { ObjectOf('Dancer::Core::App') },
);

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
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Response', @_) },
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


1;
