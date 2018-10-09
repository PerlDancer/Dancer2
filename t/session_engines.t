use strict;
use warnings;
use Test::More;
use YAML;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

use File::Spec;
use File::Basename 'dirname';
use File::Path 'rmtree';

my $SESSION_DIR;
BEGIN {
    $SESSION_DIR = File::Spec->catfile( dirname(__FILE__), 'sessions' );
}

{
    package App;
    use Dancer2;
    my @to_destroy;

    set engines => { session => { YAML => { session_dir => $SESSION_DIR } } };

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
        return exists( session->data->{'name'} ) ? "failed" : "cleared";
    };

    get '/cleanup' => sub {
        app->destroy_session;
        return scalar(@to_destroy);
    };

    setting session => 'Simple';

    set(
        show_errors  => 1,
        environment  => 'production',
    );
}

my $url  = "http://localhost";
my $test = Plack::Test->create( App->to_app );
my $app = Dancer2->runner->apps->[0];

my @clients = qw(one two three four);

for my $engine ( qw(YAML Simple) ) {
    # clear current session engine, and rebuild for the test
    # This is *really* messy, playing in object hashrefs..
    delete $app->{session_engine};
    $app->config->{session} = $engine;
    $app->session_engine; # trigger a build

    # run the tests for this engine
    for my $client (@clients) {
        my $jar = HTTP::Cookies->new;

        # this will remove the session dir before every subtest
        my $delete_session_dir = (
            $engine eq "YAML" && $client eq "four"
            ? " without session dir"
            : q{}
        );

        subtest "[$engine][$client] Empty session$delete_session_dir" => sub {
            rmtree($SESSION_DIR) if $delete_session_dir;
            my $res = $test->request( GET "$url/read_session" );
            like $res->content, qr/name=''/,
              "empty session for client $client";
            $jar->extract_cookies($res);
        };

        subtest "[$engine][$client] set_session$delete_session_dir" => sub {
            rmtree($SESSION_DIR) if $delete_session_dir;
            my $req = GET "$url/set_session/$client";
            $jar->add_cookie_header($req);
            my $res = $test->request($req);
            ok( $res->is_success, "set_session for client $client" );
            $jar->extract_cookies($res);
        };

        subtest "[$engine][$client] session for client$delete_session_dir" => sub {
            rmtree($SESSION_DIR) if $delete_session_dir;
            my $req = GET "$url/read_session";
            $jar->add_cookie_header($req);
            my $res = $test->request($req);
            if ($delete_session_dir) {
                like $res->content, qr/name=''/,
                  "session empty but we didn't blow up for client $client";
            } else {
                like $res->content, qr/name='$client'/,
                  "session looks good for client $client";
            }
            $jar->extract_cookies($res);
        };

        subtest "[$engine][$client] delete session$delete_session_dir" => sub {
            rmtree($SESSION_DIR) if $delete_session_dir;
            my $req = GET "$url/clear_session";
            $jar->add_cookie_header($req);
            my $res = $test->request($req);
            like $res->content, qr/cleared/, "deleted session key";
        };

        subtest "[$engine][$client] cleanup$delete_session_dir" => sub {
            rmtree($SESSION_DIR) if $delete_session_dir;
            my $req = GET "$url/cleanup";
            $jar->add_cookie_header($req);
            my $res = $test->request($req);
            ok( $res->is_success, "cleanup done for $client" );
            ok( $res->content, "session hook triggered" );
        };
    }
}



done_testing;
