use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

eval { require Dancer2::Session::Cookie; 1 }
  or plan skip_all => 'Dancer2::Session::Cookie probably missing.';

{
    package App;
    use Dancer2;

    set engines => {
        session => {
            Cookie => { secret_key => 'you cannot buy happiness' }
        }
    };

    set session => 'Cookie';

    get '/set' => sub {
        session foo => 'bar';
        redirect '/get';
    };

    get '/get' => sub {
        my $data = session->data;
        return to_json $data;
    };
}

my $test = Plack::Test->create( App->to_app );
my $jar  = HTTP::Cookies->new;
my $url  = 'http://localhost';
my $redir;

subtest 'Creating a session' => sub {
    my $res = $test->request( GET "$url/set" );
    ok( $res->is_redirect, 'Request causes redirect' );
    ($redir) = $res->header('Location');
    is( $redir, "/get", 'Redirects to correct url' );
    $jar->extract_cookies($res);
    ok( $jar->as_string, 'Received a session cookie' );
};

subtest 'Retrieving a session' => sub {
    my $req = GET "$url/get";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '{"foo":"bar"}', 'Correct response' );
};

done_testing;
