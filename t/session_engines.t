use strict;
use warnings;
use Test::More;
use YAML;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

my @clients = qw(one two three);
my $SESSION_DIR;

{
    package App;
    use Dancer2;
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

my $test = Plack::Test->create( App->to_app );
my $url  = "http://localhost";

foreach my $client (@clients) {
    my $jar = HTTP::Cookies->new;

    subtest "[$client] Empty session" => sub {
        my $res = $test->request( GET "$url/read_session" );
        like $res->content, qr/name=''/,
          "empty session for client $client";
        $jar->extract_cookies($res);
    };

    subtest "[$client] set_session" => sub {
        my $req = GET "$url/set_session/$client";
        $jar->add_cookie_header($req);
        my $res = $test->request($req);
        ok( $res->is_success, "set_session for client $client" );
        $jar->extract_cookies($res);
    };

    subtest "[$client] session for client" => sub {
        my $req = GET "$url/read_session";
        $jar->add_cookie_header($req);
        my $res = $test->request($req);
        like $res->content, qr/name='$client'/,
          "session looks good for client $client";
        $jar->extract_cookies($res);
    };

    subtest "[$client] delete session" => sub {
        my $req = GET "$url/clear_session";
        $jar->add_cookie_header($req);
        my $res = $test->request($req);
        like $res->content, qr/cleared/, "deleted session key";
    };

    subtest "[$client] cleanup" => sub {
        my $req = GET "$url/cleanup";
        $jar->add_cookie_header($req);
        my $res = $test->request($req);
        ok( $res->is_success, "cleanup done for $client" );
        ok( $res->content, "session hook triggered" );
    };
}

done_testing;
