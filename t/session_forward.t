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

    get '/bad_chain' => sub {
        session foo => 'SameCookieName/bad_chain';
        forward '/other/main';
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
my $base = "http://localhost:3000";

note "Forwards within a single app"; {
    # Register single app as the handler for all LWP requests.
    LWP::Protocol::PSGI->register( Test::Forward::Single->to_app );
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

# we need to make sure B doesn't override A when forwarding to C
# A -> B -> C
# This means that A (cookie_name "Homer")
#   forwarding to B (cookie_name "Marge")
#   forwarding to C (cookie_name again "Homer")
#   will cause a problem because we will lose "Homer" session data,
#   because it will be overwritten by "Marge" session data.
# Suddenly A and C cannot communicate because it was flogged.
#
# if A -> Single, B -> OtherCookieName, C -> SameCookieName
# call A, create session, then forward to B, create session,
# then forward to C, check has values as in A and C
note "Forwards between multiple apps using multiple different cookie names"; {
    my $ua = LWP::UserAgent->new;
    my $cookies_store = "$tempdir/.cookies.txt";
    $ua->cookie_jar( { file => $cookies_store } );

    my $res = $ua->get("$base/same/bad_chain");
    is(
        $res->content,
        q{SameCookieName/bad_chain:Single/outer:Single/inner},
        'session value only from apps with same session cookie name',
    );

    # cleanup.
    -e $cookies_store and unlink $cookies_store;
}

done_testing;
