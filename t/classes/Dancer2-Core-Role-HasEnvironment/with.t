use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Carp 'croak';

use Dancer2::Core::Runner;
use Dancer2::FileUtils qw/dirname path/;
use File::Spec;
use File::Temp;

# undefine ENV vars used as defaults for app environment in these tests
local $ENV{DANCER_ENVIRONMENT};
local $ENV{PLACK_ENV};

my $runner = Dancer2::Core::Runner->new();
my $location = File::Spec->rel2abs( path( dirname(__FILE__), 'config' ) );
my $location2 = File::Spec->rel2abs( path( dirname(__FILE__), 'config2' ) );

{
    package Dancer2::Test::TestRoleOne;
    use Moo;
    with 'Dancer2::Core::Role::HasEnvironment';
}

{
    undef $ENV{DANCER_ENVIRONMENT};
    undef $ENV{PLACK_ENV};
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, 'development', 'Default env is OK' );
}
{
    $ENV{DANCER_ENVIRONMENT} = 'staging';
    undef $ENV{PLACK_ENV};
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, q{staging}, 'Dancer env is OK when dancer env has value and plack env is not defined' );
}
{
    $ENV{DANCER_ENVIRONMENT} = 'staging';
    $ENV{PLACK_ENV} = 'other_env';
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, q{staging}, 'Dancer env is OK when dancer and plack env vars are both used' );
}
{
    undef $ENV{DANCER_ENVIRONMENT};
    $ENV{PLACK_ENV} = 'plack_env';
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, q{plack_env}, 'Dancer env is OK when dancer env var is not defined' );
}
{
    $ENV{DANCER_ENVIRONMENT} = '';
    $ENV{PLACK_ENV} = 'plack_env';
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, q{plack_env}, 'Dancer env is OK when one env var is empty string' );
}
{
    $ENV{DANCER_ENVIRONMENT} = '';
    $ENV{PLACK_ENV} = '';
    my $test_one = Dancer2::Test::TestRoleOne->new();
    is( $test_one->environment, q{development}, 'Dancer env is OK when both env vars are empty string' );
}

done_testing;
