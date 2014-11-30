use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

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
my $base = 'http://localhost';

subtest 'Forwards within a single app' => sub {
    my $test = Plack::Test->create( Test::Forward::Single->to_app );
    my $jar  = HTTP::Cookies->new;

    {
        my $res = $test->request( GET "$base/main" );
        is(
            $res->content,
            q{Single/main:Single/outer:Single/inner},
            'session value preserved after chained forwards',
        );

        $jar->extract_cookies($res);
    }

    {
        my $req = GET "$base/inner";
        $jar->add_cookie_header($req);

        my $res = $test->request($req);
        is(
            $res->content,
            q{Single/main:Single/outer:Single/inner},
            'session values preserved between calls',
        );

        $jar->extract_cookies($res);
    }

    {
        my $req = GET "$base/clear";
        $jar->add_cookie_header($req);

        my $res = $test->request( GET "$base/clear" );
        $jar->extract_cookies($res);
    }

    {
        my $req = GET "$base/outer";
        $jar->add_cookie_header($req);

        my $res = $test->request( GET "$base/outer" );
        is(
            $res->content,
            q{:Single/outer:Single/inner},
            'session value preserved after forward from route',
        );

        $jar->extract_cookies($res);
    }
};

subtest 'Forwards between multiple apps using the same cookie name' => sub {
    my $test = Plack::Test->create( Dancer2->psgi_app );
    my $jar  = HTTP::Cookies->new;

    {
        my $res = $test->request( GET "$base/same/main" );
        is(
            $res->content,
            q{SameCookieName/main:Single/outer:Single/inner},
            'session value preserved after chained forwards between apps',
        );

        $jar->extract_cookies($res);
    }

    {
        my $req = GET "$base/outer";
        $jar->add_cookie_header($req);

        my $res = $test->request($req);
        is(
            $res->content,
            q{SameCookieName/main:Single/outer:Single/inner},
            'session value preserved after forward from route',
        );
    }
};

subtest 'Forwards between multiple apps using different cookie names' => sub {
    my $test = Plack::Test->create( Dancer2->psgi_app );
    my $jar  = HTTP::Cookies->new;
    my $res  = $test->request( GET "$base/other/main" );

    is(
        $res->content,
        q{:Single/outer:Single/inner},
        'session value only from forwarded app',
    );
};

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
subtest 'Forwards between multiple apps using multiple different cookie names' => sub {
    my $test = Plack::Test->create( Dancer2->psgi_app );
    my $jar  = HTTP::Cookies->new;
    my $res  = $test->request( GET "$base/same/bad_chain" );

    is(
        $res->content,
        q{SameCookieName/bad_chain:Single/outer:Single/inner},
        'session value only from apps with same session cookie name',
    );
};

done_testing;
