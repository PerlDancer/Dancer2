use strict;
use warnings;
use Test::More;
use File::Spec;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;

{

    package App;
    use Dancer2;

    set engines => {
        session => {
            Simple => {cookie_name => 'dancer2.test'},
            YAML   => {cookie_name => 'dancer2.test'}
        }
    };

    set session     => 'Simple';
    set show_errors => 1;

    get '/set_session/*' => sub {
        my ($name) = splat;
        session name => $name;
    };
}

my $url  = 'http://localhost';
my $test = Plack::Test->create(App->to_app);
my $app  = Dancer2->runner->apps->[0];

my $bad_session_id = 'abcdefghijklmnopqrstuvwxyz123456';

for my $engine (qw(YAML Simple)) {

    # clear current session engine, and rebuild for the test
    # This is *really* messy, playing in object hashrefs..
    delete $app->{session_engine};
    $app->config->{session} = $engine;
    my $session_engine = $app->session_engine;    # trigger a build

    if ($session_engine->can('session_dir')) {
        # make sure our test file does not exist
        my $bad_session_file =
          File::Spec->catfile($session_engine->session_dir,
            $bad_session_id . $session_engine->_suffix);
        unlink $bad_session_file;
    }

    # run the tests for this engine

    my $jar = HTTP::Cookies->new;

    my @cookie;

    subtest "[$engine] set_session and extract cookie" => sub {
        my $res = $test->request(GET "$url/set_session/larry");
        ok($res->is_success, "set_session");

        $jar->extract_cookies($res);
        ok($jar->as_string, 'Cookie set');

        $jar->scan(sub { @cookie = @_ });
    };

    subtest "[$engine] set_session with bad cookie value" => sub {

        # set session cookie value to something bad
        $cookie[2] = $bad_session_id;
        ok($jar->set_cookie(@cookie), "Set bad cookie value");

        my $req = GET "$url/set_session/larry";
        $jar->add_cookie_header($req);
        my $res = $test->request($req);
        ok $res->is_success, "/read_session";

        $jar->clear;
        ok(!$jar->as_string, 'Jar cleared');

        $jar->extract_cookies($res);
        ok($jar->as_string, 'session cookie set again');

        my $sid;
        $jar->scan(sub { $sid = $_[2] });
        isnt $sid, 'abcdefghijklmnopqrstuvwxyz123456',
          "Session ID has been reset";
    };
}

done_testing;
