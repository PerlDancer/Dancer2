package Dancer::Core::Context;
# ABSTRACT: handles everything proper to a request's context.

use Moo;
use URI::Escape;
use Carp 'croak';

use Dancer::Core::Types;
use Dancer::Core::Request;
use Dancer::Core::Response;
use Dancer::Core::Cookie;

has app => (
    is => 'rw',
    isa => InstanceOf['Dancer::Core::App'],
    weak_ref => 1,
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
    isa => InstanceOf['Dancer::Core::Request'],
);

sub _build_request {
    my ($self) = @_;
    Dancer::Core::Request->new( env => $self->env );
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
    isa => InstanceOf['Dancer::Core::Response'],
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


=attr session

Handle for the current session object, if any

=cut

has session => (
    is      => 'rw',
    isa     => Session,
    lazy    => 1,
    builder => '_build_session',
);

sub _build_session {
    my ($self) = @_;
    my $session;

    # Find the session engine
    my $engine = $self->app->setting('session');
    croak "No session engine defined"
      if ! defined $engine;

    # find the session cookie if any
    my $session_id;
    my $session_cookie = $self->cookie('dancer.session');
    if (defined $session_cookie) {
        $session_id = $session_cookie->value;
    }
   
    # if we have a session cookie, try to retrieve the session
    if (defined $session_id) {
        eval { $session = $engine->retrieve(id => $session_id) };
        croak "Fail to retreive session: $@" 
          if $@ && $@ !~ /Unable to retrieve session/;
    }

    # create the session if none retrieved
    return $session ||= $engine->create();
}


1;
