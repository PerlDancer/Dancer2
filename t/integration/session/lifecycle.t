use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Date ();

# Session lifecycle end to end: what survives destroy_session and
# change_session_id, when the store is actually written, and what the
# Set-Cookie header says.
#
# Two things about the setup are load-bearing:
#
# 1. 'set engines' must come BEFORE 'set session'. Setting 'session' fires a
#    config trigger that builds the session engine immediately, reading the
#    'engines' config as it stands at that moment
#    (Dancer2/Core/App.pm:199-217). Written the other way round, the engine
#    options are silently ignored and every cookie assertion below would be
#    testing the defaults while appearing to test the configured values.
#
# 2. Dancer2::Session::Simple keeps all sessions in one package-level hash
#    shared by every app in the process, so a count of stored sessions is not
#    a meaningful assertion here. The tests ask whether one specific id is
#    present instead, which is unaffected by the other apps in this file.
#
# Writes to the store are counted through the engine's own
# 'engine.session.before_flush' hook - the framework's own instrumentation,
# so nothing is faked.

{
    package SessApp;
    use Dancer2;
    set logger  => 'null';
    set session => 'Simple';

    our @flushed;
    hook 'engine.session.before_flush' => sub { push @flushed, $_[0]->id };

    get '/write' => sub { session foo => 'bar'; session->id };
    get '/read'  => sub { 'foo=' . ( session('foo') // 'undef' ) };
    get '/id'    => sub { session->id };

    # Touches no session at all - not even a read.
    get '/untouched' => sub { 'nothing' };

    # Is this id in the store right now?
    get '/stored' => sub {
        my $id = query_parameters->get('id');
        return ( grep { $_ eq $id } @{ app->session_engine->sessions } )
            ? 'PRESENT'
            : 'ABSENT';
    };

    get '/destroy' => sub {
        session foo => 'bar';
        my $id = session->id;
        app->destroy_session;
        return "id=$id after=" . ( session('foo') // 'undef' );
    };

    get '/change-id' => sub {
        session foo => 'bar';
        my $old = session->id;
        my $new = app->change_session_id;
        return join ' ',
            "old=$old",
            "new=$new",
            'data=' . ( session('foo') // 'undef' ),
            'current=' . session->id;
    };
}

# Every attribute the session cookie can carry, all set at once.
{
    package HardenedApp;
    use Dancer2;
    set logger  => 'null';
    set engines => {
        session => {
            Simple => {
                cookie_name      => 'my.sid',
                cookie_path      => '/app',
                cookie_duration  => '2 hours',
                cookie_same_site => 'lax',       # deliberately lower case
                is_secure        => 1,
            }
        }
    };
    set session => 'Simple';

    get '/write' => sub { session foo => 'bar'; 'ok' };
}

{
    package NoHttpOnlyApp;
    use Dancer2;
    set logger  => 'null';
    set engines => { session => { Simple => { is_http_only => 0 } } };
    set session => 'Simple';

    get '/write' => sub { session foo => 'bar'; 'ok' };
}

# --- helpers --------------------------------------------------------------

# The cookie as a client would send it back: name=value, attributes dropped.
sub cookie_pair {
    my $set_cookie = shift;
    defined $set_cookie or return undef;
    ( my $pair = $set_cookie ) =~ s/;.*//;
    return $pair;
}

sub get_with_cookie {
    my ( $test, $path, $cookie ) = @_;
    my $req = GET "http://localhost$path";
    defined $cookie and $req->header( Cookie => $cookie );
    return $test->request($req);
}

# --- tests ---------------------------------------------------------------

subtest 'a session survives across requests and is written once' => sub {
    my $test = Plack::Test->create( SessApp->to_app );

    @SessApp::flushed = ();
    my $first = $test->request( GET '/write' );
    my $id     = $first->content;
    my $cookie = cookie_pair( $first->header('Set-Cookie') );

    ok( length $id, 'the first request has a session id' );
    ok( defined $cookie, 'and sends a session cookie' );
    is( scalar @SessApp::flushed, 1,
        'writing to the session flushes it to the store exactly once' );

    is( get_with_cookie( $test, '/read', $cookie )->content, 'foo=bar',
        'a later request carrying the cookie reads the value back' );

    is( $test->request( GET '/read' )->content, 'foo=undef',
        'a request without the cookie gets a different, empty session' );
};

subtest 'a session that was not modified is not written back' => sub {
    my $test = Plack::Test->create( SessApp->to_app );

    my $first = $test->request( GET '/write' );
    my $cookie = cookie_pair( $first->header('Set-Cookie') );

    # A read is not a modification. This is the assertion that goes red if
    # is_dirty stops gating the flush - every request would write to the
    # store, on every backend, forever.
    @SessApp::flushed = ();
    my $read = get_with_cookie( $test, '/read', $cookie );
    is( $read->content, 'foo=bar', 'the value is still readable' );
    is( scalar @SessApp::flushed, 0,
        'reading the session does not write it back to the store' );

    # No session keyword used at all, but the cookie is still echoed back so
    # the client keeps its session. Nothing is retrieved or written for it.
    @SessApp::flushed = ();
    my $untouched = get_with_cookie( $test, '/untouched', $cookie );
    is( scalar @SessApp::flushed, 0,
        'a request that never touches the session does not write it either' );
    is( cookie_pair( $untouched->header('Set-Cookie') ), $cookie,
        'and the session cookie is still returned unchanged' );

    # Without a cookie there is no session to speak of, so no cookie is set.
    my $bare = $test->request( GET '/untouched' );
    is( $bare->header('Set-Cookie'), undef,
        'a request with no cookie that never touches the session gets none' );
};

subtest 'destroy_session discards the data and expires the cookie' => sub {
    my $test = Plack::Test->create( SessApp->to_app );

    my $res = $test->request( GET '/destroy' );
    my ($id) = $res->content =~ /id=(\S+)/;

    like( $res->content, qr/after=undef/,
        'the data is gone from the session within the same request' );

    is( get_with_cookie( $test, "/stored?id=$id" )->content, 'ABSENT',
        'and the session is gone from the store' );

    my $set_cookie = $res->header('Set-Cookie');
    like( $set_cookie, qr/\bExpires=/,
        'the response cookie carries an Expires attribute' );

    my ($expires) = $set_cookie =~ /Expires=([^;]+)/;
    my $epoch = HTTP::Date::str2time($expires);
    ok( defined $epoch, "the Expires value parses as a date ($expires)" );
    cmp_ok( $epoch, '<', time,
        'and it is in the past, so the client drops the cookie' );

    # The destroyed id must not still be usable. Replaying the old cookie has
    # to produce a new session, not resurrect the old one.
    my $replay = get_with_cookie( $test, '/read', "dancer.session=$id" );
    is( $replay->content, 'foo=undef',
        'replaying the destroyed cookie does not bring the data back' );
    isnt( cookie_pair( $replay->header('Set-Cookie') ), "dancer.session=$id",
        'and a fresh session id is issued instead' );
};

subtest 'change_session_id keeps the data and retires the old id' => sub {
    my $test = Plack::Test->create( SessApp->to_app );

    my $res = $test->request( GET '/change-id' );
    my ($old) = $res->content =~ /old=(\S+)/;
    my ($new) = $res->content =~ /new=(\S+)/;

    isnt( $new, $old, 'the id actually changes' );
    like( $res->content, qr/\bdata=bar\b/,
        'the session data survives the change' );
    like( $res->content, qr/current=\Q$new\E/,
        'and the app is now on the new id' );

    is( cookie_pair( $res->header('Set-Cookie') ), "dancer.session=$new",
        'the response cookie carries the new id, not the old one' );

    # Session fixation: the old id must not remain a usable session.
    is( get_with_cookie( $test, "/stored?id=$old" )->content, 'ABSENT',
        'the old id is removed from the store' );
    is( get_with_cookie( $test, "/stored?id=$new" )->content, 'PRESENT',
        'and the new id is in the store' );

    is( get_with_cookie( $test, '/read', "dancer.session=$new" )->content,
        'foo=bar', 'the data is readable under the new id' );
    is( get_with_cookie( $test, '/read', "dancer.session=$old" )->content,
        'foo=undef', 'and not under the old one' );
};

subtest 'the session cookie is HttpOnly by default' => sub {
    my $test = Plack::Test->create( SessApp->to_app );
    my $set_cookie = $test->request( GET '/write' )->header('Set-Cookie');

    like( $set_cookie, qr/\bHttpOnly\b/,
        'HttpOnly is present without being asked for' );
    like( $set_cookie, qr{^dancer\.session=},
        'under the default cookie name' );
    like( $set_cookie, qr{\bPath=/},
        'with the default path' );

    # Off by default, and correctly so - Secure would break a plain-HTTP
    # development server. Asserted so that a change of default is visible.
    unlike( $set_cookie, qr/\bSecure\b/,
        'Secure is not set unless configured' );
    unlike( $set_cookie, qr/\bSameSite=/,
        'SameSite is not set unless configured' );
    unlike( $set_cookie, qr/\bExpires=/,
        'and there is no Expires, so it is a browser-session cookie' );
};

subtest 'configured cookie attributes reach the header' => sub {
    my $test = Plack::Test->create( HardenedApp->to_app );
    my $set_cookie = $test->request( GET '/write' )->header('Set-Cookie');

    like( $set_cookie, qr{^my\.sid=},       'cookie_name is used' );
    like( $set_cookie, qr{\bPath=/app\b},   'cookie_path is used' );
    like( $set_cookie, qr/\bSecure\b/,      'is_secure adds Secure' );
    like( $set_cookie, qr/\bHttpOnly\b/,    'HttpOnly is still there too' );

    # 'lax' was configured; the attribute coerces to ucfirst, because
    # SameSite values are case-sensitive to some clients.
    like( $set_cookie, qr/\bSameSite=Lax\b/,
        'cookie_same_site is capitalised on the way out' );

    # cookie_duration '2 hours' becomes an absolute expiry in the future.
    # The exact instant is not asserted - it depends on when the test ran.
    my ($expires) = $set_cookie =~ /Expires=([^;]+)/;
    ok( defined $expires, 'cookie_duration produces an Expires attribute' );
    my $epoch = HTTP::Date::str2time($expires);
    ok( defined $epoch, "and it parses as a date ($expires)" );
    cmp_ok( $epoch, '>', time + 3000,
        'roughly two hours ahead, not the literal string "2 hours"' );
    cmp_ok( $epoch, '<', time + 10800, 'and not much more than that' );
};

subtest 'is_http_only => 0 drops HttpOnly' => sub {
    my $test = Plack::Test->create( NoHttpOnlyApp->to_app );
    my $set_cookie = $test->request( GET '/write' )->header('Set-Cookie');

    unlike( $set_cookie, qr/\bHttpOnly\b/,
        'HttpOnly is gone when explicitly turned off' );
    like( $set_cookie, qr{^dancer\.session=},
        'but the cookie is otherwise still issued' );
};

subtest 'a cookie naming an unknown session starts a fresh one' => sub {
    my $test = Plack::Test->create( SessApp->to_app );

    # Well-formed id, but no such session. The retrieve fails and the app is
    # expected to swallow that and create a new session rather than 500.
    my $unknown = get_with_cookie(
        $test, '/read', 'dancer.session=WellFormedButNotAKnownSession'
    );
    is( $unknown->code, 200, 'an unknown session id does not blow up' );
    is( $unknown->content, 'foo=undef', 'the new session is empty' );
    isnt(
        cookie_pair( $unknown->header('Set-Cookie') ),
        'dancer.session=WellFormedButNotAKnownSession',
        'and a different id is issued rather than trusting the one supplied',
    );

    # An id that could escape a filesystem-backed store. validate_id rejects
    # it before any backend sees it, so this must not reach _retrieve.
    my $nasty = get_with_cookie( $test, '/read', 'dancer.session=../../etc/passwd' );
    is( $nasty->code, 200, 'a malformed session id does not blow up either' );
    is( $nasty->content, 'foo=undef', 'and yields an empty session' );
    unlike(
        cookie_pair( $nasty->header('Set-Cookie') ) // '',
        qr{\.\./},
        'the rejected id is not echoed back in the new cookie',
    );
};

done_testing();
