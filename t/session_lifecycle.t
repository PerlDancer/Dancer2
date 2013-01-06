use strict;
use warnings;
use Test::More;

use YAML;
use Test::TCP 1.13;
use File::Temp 0.22;
use LWP::UserAgent;
use File::Spec;

my $tempdir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);

my @engines = qw(YAML Simple);

if ($ENV{DANCER_TEST_COOKIE}) {
    push @engines, "cookie";
    setting(session_cookie_key => "secret/foo*@!");
}

foreach my $engine (@engines) {

    note "Testing engine $engine";
    Test::TCP::test_tcp(
        client => sub {
            my $port = shift;

            my $ua = LWP::UserAgent->new;
            $ua->cookie_jar({file => "$tempdir/.cookies.txt"});

            my $res = $ua->get("http://127.0.0.1:$port/no_session_data");
            ok $res->is_success, "/no_session_data";
            my @cookies = $res->header('set-cookie');
            is scalar @cookies, 0 , "no cookie set"
              or diag explain \@cookies;

            $res = $ua->get("http://127.0.0.1:$port/read_session");
            ok $res->is_success, "/read_session";
            @cookies = $res->header('set-cookie');
            is scalar @cookies, 1 , "session cookie set";
            like $res->content, qr/name=''/, "empty session";

            $res = $ua->get("http://127.0.0.1:$port/set_session/larry");
            ok $res->is_success, "/set_session/larry";

            $res = $ua->get("http://127.0.0.1:$port/read_session");
            ok $res->is_success, "/read_session";
            like $res->content, qr/name='larry'/, "session looks good";

            $res = $ua->get("http://127.0.0.1:$port/no_session_data");
            ok $res->is_success, "/no_session_data";
            @cookies = $res->header('set-cookie');
            is scalar @cookies, 1 , "session cookie set"
              or diag explain \@cookies;

            $res = $ua->get("http://127.0.0.1:$port/destroy_session");
            ok $res->is_success, "/destroy_session";
            
            $res = $ua->get("http://127.0.0.1:$port/no_session_data");
            ok $res->is_success, "/no_session_data";
            @cookies = $res->header('set-cookie');
            is scalar @cookies, 0 , "no cookie set"
              or diag explain \@cookies;

            File::Temp::cleanup();
        },
        server => sub {
            my $port = shift;

            use Dancer;
            
            get '/no_session_data' => sub {
                return "session not modified";
            };

            get '/set_session/*' => sub {
                my ($name) = splat;
                session name => $name;
            };

            get '/read_session' => sub {
                my $name = session('name') || '';
                "name='$name'";
            };

            get '/destroy_session' => sub {
                my $name = session('name') || '';
                session->destroy;
                return "destroyed='$name'";
            };

            setting appdir => $tempdir;
            setting(session => $engine);

            set(show_errors  => 1,
                startup_info => 0,
                environment  => 'production',
                port         => $port
            );
           
            Dancer->runner->server->port($port);
            start;
        },
    );
}
done_testing;


