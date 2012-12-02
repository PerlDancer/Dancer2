# ABSTRACT: Response object for Dancer

package Dancer::Core::Response;

use strict;
use warnings;
use Carp;
use Moo;
use Encode;
use Dancer::Core::Types;

use Scalar::Util qw/looks_like_number blessed/;
## use Dancer::HTTP;
use Dancer ();
use Dancer::Core::MIME;

use overload 
    '@{}' => sub { $_[0]->to_psgi },
    '""'  => sub { $_[0] };

with 'Dancer::Core::Role::Headers';

sub BUILD {
    my ($self) = @_;
    $self->header('Server' => "Perl Dancer $Dancer::VERSION");
}

# boolean to tell if the route passes or not
has has_passed => (
    is => 'rw',
    isa => Bool,
    default => sub{0},
);

sub pass { shift->has_passed(1) }

has is_encoded => (
    is => 'rw',
    isa => Bool,
    default => sub{0},
);

has is_halted => (
    is => 'rw',
    isa => Bool,
    default => sub{0},
);

sub halt { shift->is_halted(1) }

has status => (
    is => 'rw',
    isa => Num,
    default => sub { 200 },
    lazy => 1,
    coerce => sub {
        my ($status) = @_;
        return $status if looks_like_number($status);
        Dancer::HTTP->status($status);
    },
);

has content => (
    is => 'rw',
    isa => Str,
    default => sub { '' },
    coerce => sub {
        my ($value) = @_;
        $value = "$value" if ref($value);
        return $value;
    },

    # This trigger makes sure we have a good content-length whenever the content
    # changes
    trigger => sub {
        my ($self, $value) = @_;

        $self->header('Content-Length' => length($value))
         if ! $self->has_passed;

        $value;
    },
);

sub encode_content {
    my ($self) = @_;
    return if $self->is_encoded;
    return if $self->content_type !~ /^text/;
            
    # we don't want to encode an empty string, it will break the output
    return if ! $self->content;
    
    my $ct = $self->content_type;
    $self->content_type("$ct; charset=UTF-8")
      if $ct !~ /charset/;

    $self->is_encoded(1);
    my $content = $self->content(Encode::encode('UTF-8', $self->content));

    return $content;
}

sub to_psgi {
    my ($self) = @_;
    return [
        $self->status,
        $self->headers_to_array,
        [ $self->content ],
    ];
}

# sugar for accessing the content_type header, with mimetype care
sub content_type {
    my $self = shift;

    if (scalar @_ > 0) {
        my $runner = Dancer->runner;
        my $mimetype = $runner->mime_type->name_or_type(shift);
        $self->header('Content-Type' => $mimetype);
    } else {
        return $self->header('Content-Type');
    }
}

has _forward => (
    is => 'rw',
    isa => HashRef,
);

sub forward {
    my ($self, $uri, $params, $opts) = @_;
    $self->_forward({to_url => $uri, params => $params, options => $opts});
}

sub is_forwarded {
    my $self = shift;
    $self->_forward;
}

sub redirect {
    my ($self, $destination, $status) = @_;
    $self->status($status || 302);

    # we want to stringify the $destination object (URI object)
    $self->header('Location' => "$destination");
}

=method error( @args )

    $response->error( message => "oops" );

Creates a L<Dancer::Core::Error> object with the given I<@args> and I<throw()>
it against the response object. Returns the error object.

=cut

sub error {
    my $self = shift;

    my $error = Dancer::Core::Error->new(
        response => $self,
        @_,
    );

    $error->throw;

    return $error;
}

1;
__END__
