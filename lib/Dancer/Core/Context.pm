package Dancer::Core::Context;
use Moo;
use Dancer::Moo::Types;

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
    isa => sub { Dancer::Moo::Types::HashRef(@_) },
    default => sub { { headers => [] } },
);

1;
