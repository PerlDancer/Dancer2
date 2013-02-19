use Test::More tests => 3;
use Test::TCP 1.13;
use File::Temp 0.22;
use LWP::UserAgent;
use File::Spec;

use strict;
use warnings;

my $tempdir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        my $ua = LWP::UserAgent->new( 
            cookie_jar => {file => "$tempdir/cookies.txt"}
        );

        my $res = $ua->get("http://127.0.0.1:$port/");
        ok($res->is_success, "Called initial runmode");
        like($res->content,  qr{Set by t::lib::AppHooks},
            "The settings received were set in the called app");
        like($res->content,  qr{This is the flashed message},
            "And the hook set by the plugin was seen");

#    diag $res->code;
#    diag $res->content;

        File::Temp::cleanup();
    },
    server => sub {
        use Dancer '!pass';
        use t::lib::AppHooks;
        
        my $port = shift;
        set(show_errors  => 1,
            startup_info => 0,
            environment  => 'production',
            port         => $port
        );
        Dancer->runner->server->port($port);
        start;
    },
);

done_testing;
