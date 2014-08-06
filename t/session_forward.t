use Test::More;
use strict;
use warnings;
use LWP::UserAgent;
use LWP::Protocol::PSGI;

use File::Temp;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

{
    package Test::Forward::Single;
    use Dancer2;

    set session => 'Simple';

    get '/main' => sub {
        session foo => 'Single/main';
        forward '/outer';
    };

    get '/outer' => sub {
        session bar => 'Single/outer';
        forward '/inner';
    };

    get '/inner' => sub {
        session baz => 'Single/inner';
        return join ':', map +( session($_) || '' ), qw<foo bar baz>;
    };

    get '/clear' => sub {
        session foo => undef;
        session bar => undef;
        session baz => undef;
    };
}

{
    package Test::Forward::Multi::SameCookieName;
    use Dancer2;
    set session => 'Simple';
    prefix '/same';

    get '/main' => sub {
        session foo => 'SameCookieName/main';
        forward '/outer';
    };
}

{
    package Test::Forward::Multi::OtherCookieName;
    use Dancer2;
    set engines => {
        session => { Simple => { cookie_name => 'session.dancer' } }
    };

    set session => 'Simple';
    prefix '/other';

    get '/main' => sub {
        session foo => 'OtherCookieName/main';
		# Forwards to another app with different cookie name
        forward '/outer';
    };

    get '/clear' => sub {
        session foo => undef;
        session bar => undef;
        session baz => undef;
    };
}

# base uri for all requests.
my $base = "http://localhost:3000/";

note "Forwards within a single app"; {
    # Register single app as the handler for all LWP requests.
    LWP::Protocol::PSGI->register( Test::Forward::Single->psgi_app );
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/main");
    is(
        $res->content,
        q{Single/main:Single/outer:Single/inner},
        'session value preserved after chained forwards',
    );

    $res = $ua->get("$base/inner");
    is(
        $res->content,
        q{Single/main:Single/outer:Single/inner},
        'session values preserved between calls',
    );

    $res = $ua->get("$base/clear");

    $res = $ua->get("$base/outer");
    is(
        $res->content,
        q{:Single/outer:Single/inner},
        'session value preserved after forward from route',
    );

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

# Register all apps as the handler for all LWP requests.
LWP::Protocol::PSGI->register( Dancer2->psgi_app );
note "Forwards between multiple apps using the same cookie name"; {
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/same/main");
    is(
        $res->content,
        q{SameCookieName/main:Single/outer:Single/inner},
        'session value preserved after chained forwards between apps',
    );

    $res = $ua->get("$base/outer");
    is(
        $res->content,
        q{SameCookieName/main:Single/outer:Single/inner},
        'session value preserved after forward from route',
    );

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

note "Forwards between multiple apps using different cookie names"; {
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/other/main");
    is(
        $res->content,
        q{:Single/outer:Single/inner},
        'session value only from forwarded app',
    );

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

done_testing;
