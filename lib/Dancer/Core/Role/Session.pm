package Dancer::Core::Role::Session;
use Dancer::Moo::Types;
use Dancer::FileUtils qw'path';
use File::Spec;


use Moo::Role;
with 'Dancer::Core::Role::Engine';

sub type { 'Session' }

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
    isa => sub { Str(@_) },
    default => sub { _build_id() },
);

has session_name => (
    is => 'rw',
    isa => sub { Str(@_) },
    default => sub { 'dancer.session' },
);

has session_secure => (
    is => 'rw',
    isa => sub { Bool(@_) },
    default => sub { 0 },
);

has session_is_http_only => (
    is => 'rw',
    isa => sub { Bool(@_) },
    default => sub { 1 },
);

has session_expires => (
    is => 'rw',
    isa => sub { Str(@_) },
);


# Methods below this this line should not be overloaded.

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

sub read_session_id {
    my ($self) = @_;

    my $name = $self->session_name;
    my $c = $self->context->cookies->{$name};
    return (defined $c) ? $c->value : undef;
}

sub write_session_id {
    my ($self, $id) = @_;

    my $name = $self->session_name;
    my %cookie = (
        name      => $name,
        value     => $self->id,
        secure    => $self->session_secure,
        http_only => $self->session_is_http_only,
    );

    if (my $expires = $self->session_expires) {
        $cookie{expires} = $expires;
    }

    $self->context->cookies->{$name} = Dancer::Core::Cookie->new(%cookie);
}


1;
