use Test::More;
use strict;
use warnings;
use LWP::UserAgent;
use LWP::Protocol::PSGI;

use File::Temp;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

{
    package Test::Forward::SingleApp;
    use Dancer2;

    set session => 'Simple';

    get '/set_chained_session' => sub {
        session 'zbr' => 'ugh';
        forward '/set_session';
    };

    get '/set_session' => sub {
        session 'foo' => 'bar';
        forward '/get_session';
    };

    get '/get_session' => sub {
        session 'more' => 'one';
        sprintf("%s:%s:%s", session("more"), session('foo') , session('zbr')||"")
    };

    get '/clear' => sub {
        session "foo" => undef;
        session "zbr" => undef;
        session "more" => undef;
    };
}

{
    package Test::Forward::Multi::SameCookieName;
    use Dancer2;
    set session => 'Simple';
    prefix '/same';

    get '/set_chained_session' => sub {
        session 'zbr' => 'buzz';
        forward '/set_session';
    };
}

{
    package Test::Forward::Multi::OtherCookietName;
    use Dancer2;
    set engines => {
        session => { Simple => { cookie_name => 'session.dancer' } }
    };

    set session => 'Simple';
    prefix '/other';

    get '/set_chained_session' => sub {
        session 'zbr' => 'xyzzy';
		# Forwards to another app with different cookie name
        forward '/set_session';
    };

    get '/clear' => sub {
        session "foo" => undef;
        session "zbr" => undef;
        session "more" => undef;
    };
}

# base uri for all requests.
my $base = "http://localhost:3000/";

note "Forwards within a single app"; {
    # Register single app as the handler for all LWP requests.
    LWP::Protocol::PSGI->register( Test::Forward::SingleApp->psgi_app );
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/set_chained_session");
    is $res->content, q{one:bar:ugh},
        'session value preserved after chained forwards';

    $res = $ua->get("$base/get_session");
    is $res->content, q{one:bar:ugh},
        'session values preserved between calls';

    $res = $ua->get("$base/clear");

    $res = $ua->get("$base/set_session");
    is $res->content, q{one:bar:},
        'session value preserved after forward from route';

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

# Register all apps as the handler for all LWP requests.
LWP::Protocol::PSGI->register( Dancer2->psgi_app );
note "Forwards between multiple apps using the same cookie name"; {
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/same/set_chained_session");
    is $res->content, q{one:bar:buzz},
        'session value preserved after chained forwards between apps';

    $res = $ua->get("$base/set_session");
    is $res->content, q{one:bar:buzz},
        'session value preserved after forward from route';

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

note "Forwards between multiple apps using different cookie names"; {
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/other/set_chained_session");
    is $res->content, q{one:bar:}, 'session value only from forwarded app';

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

done_testing;
