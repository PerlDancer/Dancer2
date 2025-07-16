use strict;
use warnings;

use Test::More;

# undefine ENV vars used as defaults for app environment in these tests
local $ENV{DANCER_ENVIRONMENT};
local $ENV{PLACK_ENV};

{

    package Dev;
    use Moo;
    with 'Dancer2::Core::Role::HasConfig';

    sub name {'Dev'}
    sub _build_config {
        return {
            content_type => 'text/html',
            charset      => 'UTF-8',
            environment  => 'development',
            template     => 'Tiny',
        }
    }

}

my $d = Dev->new();
is $d->does('Dancer2::Core::Role::HasConfig'), 1,
    'role Dancer2::Core::Role::Config is consumed';

is $d->config->{'environment'}, 'development', 'Correct config value';
is $d->config->{'template'}, 'Tiny', 'Correct config value';
is $d->settings->{'charset'}, 'UTF-8', 'Correct config value normalized';

$d->setting( 'entry_one', 'value_one', 'entry_two', 'value_two' );
is $d->config->{'entry_one'}, 'value_one', 'Correct config value set';
is $d->config->{'entry_two'}, 'value_two', 'Correct config value set';
ok $d->has_setting('entry_one'), 'Has value we set previously';
isnt $d->has_setting('entry_missing'), 1, 'Correctly missing value';

done_testing;
