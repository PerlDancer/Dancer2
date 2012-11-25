use Test::More;
use strict;
use warnings;
use Test::TCP 1.13;
use LWP::UserAgent;
use File::Spec;
use lib File::Spec->catdir('t', 'lib');

plan tests => 2;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        use TestApp;
        use Dancer 2.0;

        set(environment  => 'production',
            startup_info => 0
        );
        Dancer->runner->server->port($port);
        start;
    },
);

#client
my $port = $server->port;
my $ua   = LWP::UserAgent->new;
my $res  = $ua->post("http://127.0.0.1:$port/params/route?a=1&var=query",
    {var => 'post', b => 2});
ok $res->is_success, 'req is success';

my $content = $res->content;
my $VAR1;
eval("$content");

my $expected = {
    body => {
        b   => 2,
        var => 'post',
    },
    params => {
        a   => 1,
        b   => 2,
        var => 'post',
    },
    query => {
        a   => 1,
        var => 'query'
    },
    route => {var => 'route'}
};
is_deeply $VAR1, $expected, "parsed params are OK";
