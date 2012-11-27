# ABSTRACT: TODO

package Dancer::Core::Role::Session;
use Dancer::Core::Types;
use Dancer::FileUtils qw'path';
use File::Spec;

use Moo::Role;
with 'Dancer::Core::Role::Engine';

sub _build_type {'Session'}

sub supported_hooks { }

# args: ($class, $id)
# receives a session id and should return a session object if found, or undef
# otherwise.
requires 'retrieve';

# args: ($class)
# create a new empty session, flush it and return it.
requires 'create';

# args: ($self)
# write the (serialized) current session to the session storage
requires 'flush';

# args: ($self)
# remove the session from the session storage
requires 'destroy';

# does nothing in most cases (exception is YAML)
sub reset { return }

has id => (
    is => 'rw',
    isa => Str,
    lazy => 1,
    builder => '_build_id',
);

# we try to make the best random number
# with native Perl 5 code.
# to rebuild a session id, an attacker should know:
# - the running PID of the server
# - the current timestamp of the time it was built
# - the path of the installation directory
# - guess the correct number between 0 and 1000000000
# - should be able to reproduce that 3 times
sub _build_id {
    my $session_id = "";
    foreach my $seed (rand(1000), rand(1000), rand(1000)) {
        my $c = 0;
        $c += ord($_) for (split //, File::Spec->rel2abs(File::Spec->curdir));
        my $current = int($seed * 1000000000) + time + $$ + $c;
        $session_id .= $current;
    }
    return $session_id;
}

has data => (
    is => 'rw',
    isa => HashRef,
    default => sub { {} },
);

has name => (
    is => 'rw',
    isa => Str,
    default => sub { 'dancer.session' },
);

has session_secure => (
    is => 'rw',
    isa => Bool,
    default => sub { 0 },
);

has session_is_http_only => (
    is => 'rw',
    isa => Bool,
    default => sub { 1 },
);

has session_expires => (
    is => 'rw',
    isa => Str,
);

# Methods below this this line should not be overloaded.

sub get_current_session {
    my ($self, $sid) = @_;

    my $session = undef;
    my $class   = ref($self);

    if (defined $sid) {
#        warn "Session ID found: $sid, trying to retreive... ($self)";
        $session = $self->retrieve($sid);
    }

    if (not defined $session) {
#        warn "session unable to retreive or no session id, creating a new one";
        $session = $class->create();
        $session->flush;
    }

    return $session;
}

sub write {
    my ($self, $key, $value) = @_;
    $self->data->{$key} = $value;
    $self->flush;
    return $value;
}

sub read {
    my ($self, $key) = @_;
    my $v = $self->data->{$key};
    return $v;
}

sub delete {
    my ($self, $key) = @_;
    delete $self->data->{$key};
    $self->flush;
}

sub cookie {
    my ($self, $id) = @_;

    my $name = $self->name;
    my %cookie = (
        name      => $name,
        value     => $self->id,
        secure    => $self->session_secure,
        http_only => $self->session_is_http_only,
        path      => '/',
    );

    if (my $expires = $self->session_expires) {
        $cookie{expires} = $expires;
    }

    Dancer::Core::Cookie->new(%cookie);
}

1;
