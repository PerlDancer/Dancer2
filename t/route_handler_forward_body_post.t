use strict;
use warnings;
use Test::More;
use Test::TCP 1.13;
use Dancer 2.0;
use LWP::UserAgent;
use HTTP::Request;
use Carp;
$Carp::Verbose = 1;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        post '/foo' => sub {
            forward '/bar';
            fail
              "This line should not be executed - forward should have aborted the route execution";
        };
        post '/bar' => sub { join(":", params) };

        post '/foz' => sub { forward '/baz'; };
        post '/baz' => sub { join(":", params('body')) };
        set startup_info => 0, show_errors => 1;
        Dancer->runner->server->port($port);
        start;
    }
);

#client
my $port     = $server->port;
my $url_base = "http://127.0.0.1:$port";
my $ua       = LWP::UserAgent->new;
my $res      = $ua->post($url_base . "/foo", {data => 'foo'});
is($res->decoded_content, "data:foo");

$res = $ua->post($url_base . "/foz", {data => 'foo'});
is($res->decoded_content, "data:foo");

done_testing;
