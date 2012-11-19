use Test::More import => ['!pass'];
use strict;
use warnings;
use Test::TCP;
use LWP::UserAgent;
use HTTP::Headers;

plan tests => 8;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        use Dancer 2.0;

        set(startup_info => 0);

        get '/req' => sub {
            request->is_ajax ? return 1 : return 0;
        };
        Dancer->runner->server->port($port);
        start;
    },
);


#client
{
    my $port = $server->port;
    my $ua   = LWP::UserAgent->new;
    my $request = HTTP::Request->new(GET => "http://127.0.0.1:$port/req");
    $request->header('X-Requested-With' => 'XMLHttpRequest');
    my $res = $ua->request($request);
    ok($res->is_success, "server responded");
    is($res->content, 1, "content ok");

    $request = HTTP::Request->new(GET => "http://127.0.0.1:$port/req");
    $res = $ua->request($request);
    ok($res->is_success, "server responded");
    is($res->content, 0, "content ok");
}

# basic interface
$ENV{REQUEST_METHOD} = 'GET';
$ENV{PATH_INFO}      = '/';

my $request = Dancer::Core::Request->new(env => \%ENV);
is $request->method, 'GET';
ok !$request->is_ajax, 'no headers';

my $headers = HTTP::Headers->new('foo' => 'bar');
$request->headers($headers);
ok !$request->is_ajax, 'no requested_with headers';

$headers = HTTP::Headers->new('X-Requested-With' => 'XMLHttpRequest');
$request->headers($headers);
ok $request->is_ajax;
