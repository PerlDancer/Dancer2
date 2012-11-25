use strict;
use warnings;
use Test::More;
use LWP::UserAgent;
use Test::TCP 1.13;

# ported from Dancer 1's t/03_route_handler/33_vars.t
# Test that vars are really reset between each request
# not sure how this is supposed to work in D2
my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        use Dancer 2.0 ":tests";

        # vars should be reset before the handler is called
        var foo          => 42;
        set startup_info => 0;
        Dancer->runner->server->port($port);

        get "/getvarfoo" => sub {
            return ++vars->{foo};
        };

        start;
    },
);

#client
my $port = $server->port;
my $ua   = LWP::UserAgent->new;
for (1 .. 10) {
    my $req = HTTP::Request->new(GET => "http://127.0.0.1:$port/getvarfoo");
    my $res = $ua->request($req);
    is $res->content, 1;
}

done_testing;
