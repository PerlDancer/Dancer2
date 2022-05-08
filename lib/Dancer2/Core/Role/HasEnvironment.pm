# ABSTRACT: Role for application environment name
package Dancer2::Core::Role::HasEnvironment;

use Moo::Role;
use Dancer2::Core::Types;

my $DEFAULT_ENVIRONMENT = q{development};

has environment => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_environment',
);

sub _build_environment {
    my ($self) = @_;
    return $ENV{DANCER_ENVIRONMENT} || $ENV{PLACK_ENV} || $DEFAULT_ENVIRONMENT;
}

1;
