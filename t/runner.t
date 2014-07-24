use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Basename 'dirname';

use Dancer2::Core::Runner;
my $runner = Dancer2::Core::Runner->new();

isa_ok $runner, 'Dancer2::Core::Runner';

note "testing environments";
is $runner->environment, 'development';

{
    local $ENV{DANCER_ENVIRONMENT} = 'production';
    my $runner = Dancer2::Core::Runner->new();
    is $runner->environment, 'production';
}

{
    local $ENV{PLACK_ENV} = 'foo';
    my $runner = Dancer2::Core::Runner->new();
    is $runner->environment, 'foo';
}

note "testing default config of the server";
is $runner->port,      3000;
is $runner->host,      '0.0.0.0';

done_testing;
