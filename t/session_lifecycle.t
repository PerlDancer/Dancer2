use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;

{
    package App;
    use Dancer2;

    set session     => 'Simple';
    set show_errors => 1;

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

    get '/change_session_id' => sub {
        my $sid1 = session->id;
        app->change_session_id;
        my $sid2 = session->id;
        return "changed from $sid1 to $sid2";
    };

    get '/destroy_session' => sub {
        my $name = session('name') || '';
        app->destroy_session;
        return "destroyed='$name'";
    };

    get '/churn_session' => sub {
        app->destroy_session;
        session name => 'damian';
        return "churned";
    };
}

my $url  = 'http://localhost';
my $jar  = HTTP::Cookies->new();
my $test = Plack::Test->create( App->to_app );

subtest 'No cookie set if session not referenced' => sub {
    my $res = $test->request( GET "$url/no_session_data" );
    ok $res->is_success, "/no_session_data"
      or diag explain $res;

    $jar->extract_cookies($res);
    ok( !$jar->as_string, 'No cookie set' );
};

subtest 'No empty session created if session read attempted' => sub {
    my $res = $test->request( GET "$url/read_session" );
    ok $res->is_success, "/read_session";

    $jar->extract_cookies($res);
    ok( !$jar->as_string, 'No cookie set' );
};

my $sid1;
subtest 'Set value into session' => sub {
    my $res = $test->request( GET "$url/set_session/larry" );
    ok $res->is_success, "/set_session/larry";

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'Cookie set' );

    # extract SID
    $jar->scan( sub { $sid1 = $_[2] } );
    ok( $sid1, 'Got SID from cookie' );
};

subtest 'Read value back' => sub {
    # read value back
    my $req = GET "$url/read_session";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok $res->is_success, "/read_session";

    $jar->clear;
    ok( !$jar->as_string, 'Jar cleared' );

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set again' );
    like $res->content, qr/name='larry'/, "session value looks good";
};

subtest 'Session cookie persists even if we do not touch sessions' => sub {
    my $req = GET "$url/no_session_data";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/no_session_data";

    $jar->clear;
    ok( !$jar->as_string, 'Jar cleared' );

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set again' );
};

my $sid2;
subtest 'Change session ID' => sub {
    my $req = GET "$url/change_session_id";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok $res->is_success, "/change_session_id";

    $jar->clear;
    ok( !$jar->as_string, 'Jar cleared' );

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set again' );

    # extract SID
    $jar->scan( sub { $sid2 = $_[2] } );
    isnt $sid2, $sid1, "New session has different ID";
};

subtest 'Read value back after change_session_id' => sub {
    # read value back
    my $req = GET "$url/read_session";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok $res->is_success, "/read_session";

    $jar->clear;
    ok( !$jar->as_string, 'Jar cleared' );

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set again' );
    like $res->content, qr/name='larry'/, "session value looks good";
};

subtest 'Destroy session and check that cookies expiration is set' => sub {
    my $req = GET "$url/destroy_session";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/destroy_session";

    ok( $jar->as_string, 'We have a cookie before reading response' );
    $jar->extract_cookies($res);
    ok( ! $jar->as_string, 'Cookie was removed from jar' );
};

subtest 'Session cookie not sent after session destruction' => sub {
    my $req = GET "$url/no_session_data";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/no_session_data";

    ok( !$jar->as_string, 'Jar is empty' );
    $jar->extract_cookies($res);
    ok( !$jar->as_string, 'Jar still empty (no new session cookie)' );
};

my $sid3;
subtest 'Set value into session again' => sub {
    my $res = $test->request( GET "$url/set_session/curly" );
    ok $res->is_success, "/set_session/larry";

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set' );

    # extract SID
    $jar->scan( sub { $sid3 = $_[2] } );
    isnt $sid3, $sid2, "New session has different ID";
};

subtest 'Destroy and create a session in one request' => sub {
    my $req = GET "$url/churn_session";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/churn_session";

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set' );

    my $sid4;
    $jar->scan( sub { $sid4 = $_[2] } );
    isnt $sid4, $sid3, "Changed session has different ID";
};

subtest 'Read value back' => sub {
    my $req = GET "$url/read_session";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/read_session";

    $jar->extract_cookies($res);
    ok( $jar->as_string, "session cookie set" );
    like $res->content, qr/name='damian'/, "session value looks good";
};

done_testing;
