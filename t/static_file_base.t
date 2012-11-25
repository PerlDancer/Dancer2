use strict;
use warnings;
use Test::More;
use Plack::Loader;
use Dancer 2.0;
use Dancer::Test;
use HTTP::Date qw( time2str );
use Test::TCP 1.13;
use HTTP::Request;
use LWP::UserAgent;


$ENV{PERL_ONLY} = 1;
# There is an issue with HTTP::Parser::XS while parsing an URI with \0
# Using the pure perl via PERL_ONLY works
# test ported from D1 t/04_static_file/001_base.t

set public => path(dirname(__FILE__), 'static');
my $public = setting('public');
my $hello="$public/hello.txt";
ok (-f $hello, 'file exists');
my $date   = time2str((stat $hello)[9]);
my $req = [GET => '/hello.txt'];
response_is_file $req;

my $res = Dancer::Test::get_file_response($req);
is_deeply(
    $res->headers_to_array,
    ['Content-Type' => 'text/plain', 'Last-Modified' => $date],
    "response header looks good for @$req"
);
is(ref($res->{content}), 'GLOB', "response content looks good for @$req");

ok $res = Dancer::Test::get_file_response([GET => "/hello\0.txt"]);
is $res->status,  400;
is $res->content, 'Bad Request';

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        setting apphandler => 'PSGI';
        Plack::Loader->auto(port => $port)
          ->run(Dancer->runner->server->psgi_app);
    }
);

#client
my $port = $server->port;
$req  = HTTP::Request->new(GET => "http://127.0.0.1:$port/hello%00.txt");
my $ua   = LWP::UserAgent->new();
$res  = $ua->request($req);
ok !$res->is_success;
is $res->code, 400;

$req = HTTP::Request->new(
    GET => "http://127.0.0.1:$port/hello.txt",
    ['If-Modified-Since' => $date]
);
$ua  = LWP::UserAgent->new();
$res = $ua->request($req);
ok !$res->is_success;
is $res->code, 304;

done_testing;
