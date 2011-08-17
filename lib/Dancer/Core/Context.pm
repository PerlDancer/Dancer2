package Dancer::Core::Context;
use Moo;
use Dancer::Moo::Types;

# a buffer for per-request variables
has buffer => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef(@_) },
    default => sub { {} },
);

# the incoming request 
has request => (
    is => 'ro',
    required => 1,
    isa => sub { Dancer::Moo::Types::ObjectOf('Dancer::Core::Request' => @_) },
);

# a set of changes to apply to the response
# that HashRef will should be passed as attributes to a response object
has response_attributes => (
    is => 'rw',
    isa => sub { Dancer::Moo::Types::HashRef(@_) },
    default => sub { { headers => [] } },
);

1;
