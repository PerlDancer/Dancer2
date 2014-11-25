use strict;
use warnings;
use Test::More;

use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;

{
    package TestApp;

    use Dancer2;

    get '/' => sub {
        template 'session_in_template'
    };

    get '/set_session/*' => sub {
        my ($name) = splat;
        session name => $name;
        template 'session_in_template';
    };

    get '/destroy_session' => sub {
        # Need to call the 'session' keyword, so app->setup_session
        # is called and the session attribute in the engines is populated
        my $name = session 'name';
        # Destroying the session should remove the session object from
        # all engines.
        app->destroy_session;
        template 'session_in_template';
    };

    setting(
        engines => {
            session => { 'Simple' => { session_dir => 't/sessions' } }
        }
    );
    setting( session => 'Simple' );
}

my $app = TestApp->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);
my $jar = HTTP::Cookies->new();

{
    my $res = $test->request( GET '/' );

    ok $res->is_success, 'Successful request';
    is $res->content, "session.name \n";

    $jar->extract_cookies($res);
}

{
    my $request = GET '/set_session/test_name';
    $jar->add_cookie_header($request);

    my $res = $test->request($request);
    ok $res->is_success, 'Successful request';
    is $res->content, "session.name test_name\n";

    $jar->extract_cookies($res);
}

{
    my $request = GET '/destroy_session';
    $jar->add_cookie_header($request);

    my $res = $test->request($request);
    ok $res->is_success, 'Successful request';
    is $res->content, "session.name \n";

    $jar->extract_cookies($res);
}

done_testing();
