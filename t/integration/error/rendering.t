use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

# Error page rendering: what gets shown, what gets hidden, and what happens
# when the thing meant to render the error is itself broken.
#
# The stack trace and the settings/session/environment dumps only appear when
# show_stacktrace is on AND the status is 5xx (Dancer2/Core/Error.pm:156). That
# conjunction is the whole point of these tests: a 4xx must not leak the
# environment even on a box where show_stacktrace was left on, and the censor
# only runs on the path that produces those dumps.

{
    package ErrorApp;
    use Dancer2;
    set logger          => 'null';
    set show_stacktrace => 1;
    set session         => 'Simple';

    # Settings that the environment dump will walk over. Three should be
    # censored by the default pattern (pass|card.?num|pan|secret), one should
    # not - otherwise "nothing leaked" could just mean "nothing was dumped".
    set my_password    => 'PASSWORD-MUST-NOT-LEAK';
    set card_number    => '4111111111111111';
    set api_secret     => 'SECRET-MUST-NOT-LEAK';
    set harmless_value => 'HARMLESS-AND-VISIBLE';

    get '/die'      => sub { die "kaboom\n" };
    get '/error500' => sub { send_error( 'explicit five hundred', 500 ) };
    get '/error404' => sub { send_error( 'no such thing',         404 ) };
    get '/error400' => sub { send_error( 'bad input',             400 ) };
    get '/error403' => sub { send_error( 'not allowed',           403 ) };

    get '/session-die' => sub {
        session password => 'SESSION-SECRET-MUST-NOT-LEAK';
        session nick     => 'ovid';
        die "boom with a session\n";
    };

    get '/html-400' => sub {
        send_error( q{<script>alert(1)</script> & "quoted" and 'single'}, 400 );
    };
    get '/html-500' => sub {
        send_error( q{<script>alert(1)</script> & "quoted"}, 500 );
    };
}

my $test = Plack::Test->create( ErrorApp->to_app );

subtest 'a 5xx with show_stacktrace on renders the full diagnostic page' => sub {
    for my $path ( '/die', '/error500' ) {
        my $response = $test->request( GET $path );
        my $body     = $response->content;

        is( $response->code, 500, "$path: is a 500" );
        like( $body, qr/<div class="title">Stack</,      "$path: shows the stack" );
        like( $body, qr/<div class="title">Settings</,   "$path: dumps settings" );
        like( $body, qr/<div class="title">Session</,    "$path: dumps the session" );
        like( $body, qr/<div class="title">Environment</,"$path: dumps the environment" );
    }
};

subtest 'a 4xx never shows a stack trace, even with show_stacktrace on' => sub {
    # This is the assertion that matters: the setting is on for this whole
    # app, and the 5xx subtest above proves it is working.
    for my $path ( '/error400', '/error403', '/error404' ) {
        my $response = $test->request( GET $path );
        my $body     = $response->content;

        unlike( $body, qr/<div class="title">Stack</,
            "$path: no stack" );
        unlike( $body, qr/<div class="title">Settings</,
            "$path: no settings dump" );
        unlike( $body, qr/<div class="title">Environment</,
            "$path: no environment dump" );

        # Nothing from the settings reaches a 4xx page at all.
        unlike( $body, qr/HARMLESS-AND-VISIBLE/,
            "$path: not even a harmless setting is dumped" );

        # It is still a recognisable error page with its own status in it.
        like( $body, qr/<!DOCTYPE html>/, "$path: still renders an error page" );
    }

    is( $test->request( GET '/error404' )->code, 404, '404 keeps its status' );
    is( $test->request( GET '/error400' )->code, 400, '400 keeps its status' );
};

subtest 'sensitive-looking settings are censored from the dump' => sub {
    my $body = $test->request( GET '/die' )->content;

    # The control first: if this fails, the dump is not happening and the
    # absences below prove nothing.
    like( $body, qr/HARMLESS-AND-VISIBLE/,
        'a non-sensitive setting does appear in the dump' );
    like( $body, qr/harmless_value/, 'under its own key' );

    # The keys are still listed - it is the values that are replaced, so the
    # developer can see what was hidden.
    like( $body, qr/my_password/, 'the sensitive key is still shown' );
    like( $body, qr/card_number/, 'and so is the card number key' );
    like( $body, qr/api_secret/,  'and the secret key' );

    unlike( $body, qr/PASSWORD-MUST-NOT-LEAK/,
        'a value under a key matching "pass" is not shown' );
    unlike( $body, qr/4111111111111111/,
        'a value under a key matching "card.?num" is not shown' );
    unlike( $body, qr/SECRET-MUST-NOT-LEAK/,
        'a value under a key matching "secret" is not shown' );

    like( $body, qr/Hidden \(looks potentially sensitive\)/,
        'the replacement text is shown in their place' );
    like( $body, qr/sensitive-looking keys hidden/,
        'and the page says how many values were hidden' );
};

subtest 'sensitive-looking session values are censored too' => sub {
    my $body = $test->request( GET '/session-die' )->content;

    like( $body, qr/<div class="title">Session</,
        'the session is dumped' );
    like( $body, qr/ovid/,
        'an ordinary session value is visible' );
    unlike( $body, qr/SESSION-SECRET-MUST-NOT-LEAK/,
        'but a session value under a "password" key is not' );
};

subtest 'an error message containing HTML is escaped, not rendered' => sub {
    # A 4xx takes the _html_encode branch; a 5xx takes the backtrace branch.
    # Both encode, but by different code, so both are checked.
    for my $path ( '/html-400', '/html-500' ) {
        my $body = $test->request( GET $path )->content;

        unlike( $body, qr/<script>alert\(1\)<\/script>/,
            "$path: the script tag is not emitted raw" );
        like( $body, qr/&lt;script&gt;/,
            "$path: it is escaped instead" );
        like( $body, qr/&amp;/,
            "$path: the ampersand is escaped" );
        unlike( $body, qr/"quoted"/,
            "$path: double quotes are escaped" );
        like( $body, qr/&quot;quoted&quot;/,
            "$path: to &quot; entities" );
    }

    # Single quotes matter for attribute-context injection, and only the 4xx
    # path puts the message where that could apply.
    my $body_400 = $test->request( GET '/html-400' )->content;
    like( $body_400, qr/&#39;single&#39;/, 'single quotes are escaped as well' );
};

done_testing();
