# ABSTRACT: Response object for Dancer2

package Dancer2::Core::Response;

use strict;
use warnings;
use Carp;
use Moo;
use Encode;
use Dancer2::Core::Types;

use Scalar::Util qw/looks_like_number blessed/;
## use Dancer2::HTTP;
use Dancer2 ();
use Dancer2::Core::MIME;

use overload
  '@{}' => sub { $_[0]->to_psgi },
  '""'  => sub { $_[0] };

with 'Dancer2::Core::Role::Headers';

sub BUILD {
    my ($self) = @_;
    $self->header('Server' => "Perl Dancer2 $Dancer2::VERSION");
}

# boolean to tell if the route passes or not
has has_passed => (
    is      => 'rw',
    isa     => Bool,
    default => sub {0},
);

sub pass { shift->has_passed(1) }

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

sub halt { shift->is_halted(1) }

has status => (
    is      => 'rw',
    isa     => Num,
    default => sub {200},
    lazy    => 1,
    coerce  => sub {
        my ($status) = @_;
        return $status if looks_like_number($status);
        Dancer2::HTTP->status($status);
    },

    # This trigger makes sure we drop the content whenever
    # we set the status to [23]04.
    trigger => sub {
        my ($self, $value) = @_;
        $self->content('') if $value =~ /^(?:1\d{2}|[23]04)$/;
        $value;
    },
);

has content => (
    is      => 'rw',
    isa     => Str,
    default => sub {''},
    coerce  => sub {
        my ($value) = @_;
        $value = "$value" if ref($value);
        return $value;
    },

   # This trigger makes sure we have a good content-length whenever the content
   # changes
    trigger => sub {
        my ($self, $value) = @_;

        $self->header('Content-Length' => length($value))
          if !$self->has_passed;

        $value;
    },
);

sub encode_content {
    my ($self) = @_;
    return if $self->is_encoded;
    return if $self->content_type !~ /^text/;

    # we don't want to encode an empty string, it will break the output
    return if !$self->content;

    my $ct = $self->content_type;
    $self->content_type("$ct; charset=UTF-8")
      if $ct !~ /charset/;

    $self->is_encoded(1);
    my $content = $self->content(Encode::encode('UTF-8', $self->content));

    return $content;
}

sub to_psgi {
    my ($self) = @_;
    return [$self->status, $self->headers_to_array, [$self->content],];
}

# sugar for accessing the content_type header, with mimetype care
sub content_type {
    my $self = shift;

    if (scalar @_ > 0) {
        my $runner   = Dancer2->runner;
        my $mimetype = $runner->mime_type->name_or_type(shift);
        $self->header('Content-Type' => $mimetype);
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

Creates a L<Dancer2::Core::Error> object with the given I<@args> and I<throw()>
it against the response object. Returns the error object.

=cut

sub error {
    my $self = shift;

    my $error = Dancer2::Core::Error->new(
        response => $self,
        @_,
    );

    $error->throw;

    return $error;
}

1;

