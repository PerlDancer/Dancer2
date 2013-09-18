use strict;
use warnings;
use Test::More;

use YAML;
use Test::TCP 1.13;
use File::Temp 0.22;
use LWP::UserAgent;
use File::Spec;
use Net::EmptyPort qw(empty_port);

# Find an empty port BEFORE importing Dancer2
my $port;
BEGIN { $port = empty_port }

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

my @clients = qw(one two three);
my @engines = qw(YAML Simple);
my $SESSION_DIR;

if ( $ENV{DANCER_TEST_COOKIE} ) {
    push @engines, "cookie";
    setting( session_cookie_key => "secret/foo*@!" );
}

foreach my $engine (@engines) {

    note "Testing engine $engine";

    my $server = Test::TCP->new( port => $port, code => sub {
            use Dancer2 port => $port, show_errors  => 1,
                startup_info => 0, environment => 'production';

            my @to_destroy;

            hook 'engine.session.before_destroy' => sub {
                my $session = shift;
                push @to_destroy, $session;
            };

            get '/set_session/*' => sub {
                my ($name) = splat;
                session name => $name;
            };

            get '/read_session' => sub {
                my $name = session('name') || '';
                "name='$name'";
            };

            get '/clear_session' => sub {
                session name => undef;
                return exists( session->data->{name} ) ? "failed" : "cleared";
            };

            get '/cleanup' => sub {
                context->destroy_session;
                return scalar(@to_destroy);
            };

            setting appdir => $tempdir;
            setting(
                engines => {
                    session => { $engine => { session_dir => 't/sessions' } }
                }
            );
            setting( session => $engine );

            start;
    });

    foreach my $client (@clients) {
        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar( { file => "$tempdir/.cookies.txt" } );

        my $res = $ua->get("http://127.0.0.1:$port/read_session");
        like $res->content, qr/name=''/,
          "empty session for client $client";

        $res = $ua->get("http://127.0.0.1:$port/set_session/$client");
        ok( $res->is_success, "set_session for client $client" );

        $res = $ua->get("http://127.0.0.1:$port/read_session");
        like $res->content, qr/name='$client'/,
          "session looks good for client $client";

        $res = $ua->get("http://127.0.0.1:$port/clear_session");
        like $res->content, qr/cleared/, "deleted session key";

        $res = $ua->get("http://127.0.0.1:$port/cleanup");
        ok( $res->is_success, "cleanup done for $client" );

        ok( $res->content, "session hook triggered" );

    }

    File::Temp::cleanup();

}

done_testing;

