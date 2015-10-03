use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    setting(
        engines => {
            session => {
                Simple => {
                    cookie_name     => 'dancer.sid',
                    cookie_path     => '/foo',
                    cookie_duration => '1 hour',
                    is_http_only    => 0, # will not show up in cookie
                },
            },
        }
    );

    setting( session => 'Simple' );

    get '/has_session' => sub {
        return app->has_session;
    };

    get '/foo/set_session/*' => sub {
        my ($name) = splat;
        session name => $name;
    };

    get '/foo/read_session' => sub {
        my $name = session('name') || '';
        "name='$name'";
    };

    get '/foo/destroy_session' => sub {
        my $name = session('name') || '';
        app->destroy_session;
        return "destroyed='$name'";
    };
}

my $test = Plack::Test->create( App->to_app );
my $url  = 'http://localhost';

my $jar = HTTP::Cookies->new;

subtest 'Set session' => sub {
    my $res = $test->request( GET "$url/foo/set_session/larry" );
    ok( $res->is_success, '/foo/set_session/larry' );

    $jar->extract_cookies($res);
    ok( $jar->as_string, 'session cookie set' );

    my ( $expires, $domain, $path, $opts );
    my $cookie = $jar->scan( sub {
        ( $expires, $domain, $path, $opts ) = @_[ 8, 4, 3 ];
    } );

    my $httponly = $opts->{'HttpOnly'};

    ok $expires - time > 3540,
      "cookie expiration is in future";

    is $domain, 'localhost.local', "cookie domain set";
    is $path, '/foo', "cookie path set";
    is $httponly, undef, "cookie has not set HttpOnly";

    # read value back
};

subtest 'Read session' => sub {
    my $req = GET "$url/foo/read_session";
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    ok $res->is_success, "/foo/read_session";
    like $res->content, qr/name='larry'/, "session value looks good";
};

done_testing;
