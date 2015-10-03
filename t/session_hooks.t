use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;

my @hooks_to_test = qw(
  engine.session.before_retrieve
  engine.session.after_retrieve

  engine.session.before_create
  engine.session.after_create

  engine.session.before_destroy
  engine.session.after_destroy

  engine.session.before_flush
  engine.session.after_flush
);

# we'll set a flag here when each hook is called. Then our test will then verify this
my $test_flags = {};

{
    package App;
    use Dancer2;

    set(
        show_errors => 1,
        envoriment  => 'production'
    );

    setting( session => 'Simple' );

    for my $hook (@hooks_to_test) {
        hook $hook => sub {
            $test_flags->{$hook} ||= 0;
            $test_flags->{$hook}++;
        }
    }

    get '/set_session' => sub {
        session foo => 'bar'; #setting causes a session flush
        return "ok";
    };

    get '/get_session' => sub {
        ::is session->read('foo'), 'bar', "Got the right session back";
        return "ok";
    };

    get '/destroy_session' => sub {
        app->destroy_session;
        return "ok";
    };

    #setup each hook again and test whether they return the correct type
    #there is unfortunately quite some duplication here.
    hook 'engine.session.before_create' => sub {
        my ($response) = @_;
        ::isa_ok( $response, 'Dancer2::Core::Session' );
    };

    hook 'engine.session.after_create' => sub {
        my ($response) = @_;
        ::isa_ok( $response, 'Dancer2::Core::Session' );
    };

    hook 'engine.session.after_retrieve' => sub {
        my ($response) = @_;
        ::isa_ok( $response, 'Dancer2::Core::Session' );
    };
}

my $test = Plack::Test->create( App->to_app );
my $jar  = HTTP::Cookies->new;
my $url  = "http://localhost";

is_deeply( $test_flags, {}, 'Make sure flag hash is clear' );

subtest set_session => sub {
    my $res = $test->request( GET "$url/set_session" );
    is $res->content, "ok", "set_session ran ok";
    $jar->extract_cookies($res);
};

# we verify whether the hooks were called correctly.
subtest 'verify hooks for session create and session flush' => sub {
    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create called";
    is $test_flags->{'engine.session.before_flush'}, 1, "session.before_flush called";
    is $test_flags->{'engine.session.after_flush'}, 1, "session.after_flush called";

    is $test_flags->{'engine.session.before_retrieve'}, undef, "session.before_retrieve not called";
    is $test_flags->{'engine.session.after_retrieve'}, undef, "session.after_retrieve not called";
    is $test_flags->{'engine.session.before_destroy'}, undef, "session.before_destroy not called";
    is $test_flags->{'engine.session.after_destroy'}, undef, "session.after_destroy not called";
};

subtest 'verify Handler::File (static content) does not retrieve session' => sub {
    my $req = GET "$url/file.txt";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    $jar->extract_cookies($res);

    # These should not change from previous subtest
    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create not called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create not called";
    is $test_flags->{'engine.session.before_retrieve'}, undef, "session.before_retrieve not called";
    is $test_flags->{'engine.session.after_retrieve'}, undef, "session.after_retrieve not called";
};

subtest get_session => sub {
    my $req = GET "$url/get_session";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    is $res->content, "ok", "get_session ran ok";
    $jar->extract_cookies($res);
};

subtest 'verify hooks for session retrieve' => sub {
    is $test_flags->{'engine.session.before_retrieve'}, 1, "session.before_retrieve called";
    is $test_flags->{'engine.session.after_retrieve'}, 1, "session.after_retrieve called";

    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create not called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create not called";
    is $test_flags->{'engine.session.before_flush'}, 1, "session.before_flush not called";
    is $test_flags->{'engine.session.after_flush'}, 1, "session.after_flush not called";
    is $test_flags->{'engine.session.before_destroy'}, undef, "session.before_destroy not called";
    is $test_flags->{'engine.session.after_destroy'}, undef, "session.after_destroy not called";
};

subtest destroy_session => sub {
    my $req = GET "$url/destroy_session";
    $jar->add_cookie_header($req);
    my $res = $test->request($req);
    is $res->content, "ok", "destroy_session ran ok";
};

subtest 'verify session destroy hooks' => sub {
    is $test_flags->{'engine.session.before_destroy'}, 1, "session.before_destroy called";
    is $test_flags->{'engine.session.after_destroy'}, 1, "session.after_destroy called";
    #not sure if before and after retrieve should be called when the session is destroyed. But this happens.
    is $test_flags->{'engine.session.before_retrieve'}, 2, "session.before_retrieve called";
    is $test_flags->{'engine.session.after_retrieve'}, 2, "session.after_retrieve called";

    is $test_flags->{'engine.session.before_create'}, 1, "session.before_create not called";
    is $test_flags->{'engine.session.after_create'}, 1, "session.after_create not called";
    is $test_flags->{'engine.session.before_flush'}, 1, "session.before_flush not called";
    is $test_flags->{'engine.session.after_flush'}, 1, "session.after_flush not called";
};

done_testing;
