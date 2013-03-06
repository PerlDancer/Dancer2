use strict;
use warnings;

use File::Spec;
use File::Temp 0.22;
use LWP::UserAgent;
use Test::More;
use Test::TCP 1.13;
use YAML;

my $tempdir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar({file => "$tempdir/.cookies.txt"});

        my $res = $ua->get("http://127.0.0.1:$port/main");
        for my $type ( qw/session logger serializer template/ ) {
            like $res->content, qr/^$type 1$/ms, "$type has context"
        }

        File::Temp::cleanup();
    },
    server => sub {
        my $port = shift;

        BEGIN {
            use Dancer2;
            set session => 'Simple';
            set logger => 'Null';
            set serializer => 'JSON';
            set template => 'Simple';
        }

        get '/main' => sub {
            my $response = "";
            for my $type ( qw/session logger serializer template/ ) {
                my $defined = defined(engine("$type")->context) ? 1 : 0;
                $response .="$type $defined\n";
            }
            return $response;
        };

        setting appdir => $tempdir;
        Dancer2->runner->server->port($port);
        start;
    },
);

done_testing;
