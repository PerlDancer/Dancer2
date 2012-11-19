use Test::More import => ['!pass'];
use strict;
use warnings;
use Dancer;
use File::Spec;
use lib File::Spec->catdir('t', 'lib');
use Test::TCP;
use LWP::UserAgent;

use constant RAW_DATA => "var: 2; foo: 42; bar: 57\nHey I'm here.\r\n\r\n";

plan tests => 2;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        use TestApp;

        set(environment => 'production',
            startup_info => 0  #seems not to work yet in Dancer 2.0
        );
        Dancer->runner->server->port($port);
        start;
    },
);

my $port    = $server->port;
my $rawdata = RAW_DATA;
my $client  = LWP::UserAgent->new;
my $req     = HTTP::Request->new(PUT => "http://127.0.0.1:$port/jsondata");
my $headers = {'Content-Length' => length($rawdata)};
$req->push_header($_, $headers->{$_}) foreach keys %$headers;
$req->content($rawdata);
my $res = $client->request($req);

ok $res->is_success, 'req is success';
is $res->content, $rawdata, "raw_data is OK";
