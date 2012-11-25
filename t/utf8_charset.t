use strict;
use warnings;
use utf8;
use Encode qw(encode decode);
use Test::More import => ['!pass'];
use LWP::UserAgent;
use Test::TCP 1.13;

#from Dancer1's t/00_base/12_utf8_charset.t
#see also charset_server.t for related tests

plan tests => 4;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;
        use Dancer 2.0;
        use t::lib::TestAppUnicode;

        set(charset      => 'utf8',
            show_errors  => 1,
            startup_info => 0,
            log          => 'debug',
            logger       => 'console'
        );
        Dancer->runner->server->port($port);

        start;
    },
);

#client
my $port = $server->port;
my $res;

$res = _get_http_response(GET => '/string', $port);
is d($res->content), "\x{1A9}", "utf8 static response";

$res = _get_http_response(GET => '/other/string', $port);
is d($res->content), "\x{1A9}", "utf8 response through forward";

$res = _get_http_response(GET => "/param/" . u("\x{1A9}"), $port);
is d($res->content), "\x{1A9}", "utf8 route param";

$res = _get_http_response(GET => "/view?string1=" . u("\x{E9}"), $port);
is d($res->content), "sigma: 'Ʃ'\npure_token: 'Ʃ'\nparam_token: '\x{E9}'\n",
  "params and tokens are valid unicode";

#
# subs
#

sub u {
    encode('UTF-8', $_[0]);
}

sub d {
    decode('UTF-8', $_[0]);
}

sub _get_http_response {
    my ($method, $path, $port) = @_;

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new($method => "http://127.0.0.1:$port${path}");
    return $ua->request($req);
}

