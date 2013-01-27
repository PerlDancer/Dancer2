use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Basename 'dirname';

use Dancer::Core::Runner;
my $runner = Dancer::Core::Runner->new(caller => __FILE__);

isa_ok $runner, 'Dancer::Core::Runner';
is $runner->location, File::Spec->rel2abs(dirname(__FILE__)),
  "location is set correctly";

note "testing environments";
is $runner->environment, 'development';

{
    local $ENV{DANCER_ENVIRONMENT} = 'production';
    my $runner = Dancer::Core::Runner->new(caller => __FILE__);
    is $runner->environment, 'production';
}

{
    local $ENV{PLACK_ENV} = 'foo';
    my $runner = Dancer::Core::Runner->new(caller => __FILE__);
    is $runner->environment, 'foo';
}

is $runner->server->name, 'Standalone', "server is created and is standalone";

note "testing default config of the server";
is $runner->server->port,      3000;
is $runner->server->host,      '0.0.0.0';
is $runner->server->is_daemon, 0;

note "testing server failure";
{
    $runner->config->{apphandler} = 'NotExist';
    like(
        exception { Dancer::Core::Runner::_build_server($runner) },
        qr{Unable to load Dancer::Core::Server::NotExist},
        'Cannot run BUILD for server that does not exist',
    );
}

done_testing;
