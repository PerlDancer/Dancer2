use strict;
use warnings;
use Test::More tests => 6;
use Dancer2::Core::Runner;

# undefine ENV vars used as defaults for app environment in these tests
local $ENV{DANCER_ENVIRONMENT};
local $ENV{PLACK_ENV};

{
    my $runner = Dancer2::Core::Runner->new();
    isa_ok( $runner, 'Dancer2::Core::Runner' );

    is(
        $runner->environment,
        'development',
        'Default environment',
    );
}

{
    local $ENV{DANCER_ENVIRONMENT} = 'foo';
    my $runner = Dancer2::Core::Runner->new();
    isa_ok( $runner, 'Dancer2::Core::Runner' );
    is(
        $runner->environment,
        'foo',
        'Successfully set envinronment using DANCER_ENVIRONMENT',
    );
}

{
    local $ENV{PLACK_ENV} = 'bar';
    my $runner = Dancer2::Core::Runner->new();
    isa_ok( $runner, 'Dancer2::Core::Runner' );
    is(
        $runner->environment,
        'bar',
        'Successfully set environment using PLACK_ENV',
    );
}

