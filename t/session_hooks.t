use strict;
use warnings;
use Test::More;

use File::Temp 0.22;
use YAML;

use LWP::UserAgent;

eval "use LWP::Protocol::PSGI";
plan skip_all => "LWP::Protocol::PSGI is needed for this test" if $@;

my @engines = qw(Simple);

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
#we'll set a flag here when each hook is called. Then our test will then verify this
my $test_flags = {};
my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

#I need this to make sure it works with LWP::Protocol::PSGI See GH#447
BEGIN {
    $ENV{DANCER_APPHANDLER} = 'PSGI';
}

sub get_app_for_engine {
    my $engine = shift;
    use Dancer2;

    #Possibly this doesn't seem to have a real effect. See GH#447
    setting apphandler => 'PSGI';
    setting appdir => $tempdir;
    setting(
            engines => { #we'll need this for YAML sessions
                session => { engine => {session_dir => 't/sessions'}}
            }
    );
    set(show_errors  => 1,
        startup_info => 0,
        envoriment   => 'production'
    );
    setting(session => $engine);

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
      is session->read('foo'), 'bar', "Got the right session back";
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
       is ref($response), 'Dancer2::Core::Session',
                           'Correct response type returned in before_create';
    };
    hook 'engine.session.after_create' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session',
                            'Correct response type returned in after_create';
    };
    hook 'engine.session.after_retrieve' => sub {
       my ($response) = @_;
       is ref($response), 'Dancer2::Core::Session',
                            'Correct response type returned in before_retrieve';
    };
    #this returns dancer app. We'll register it with LWP::Protocol::PSGI
    dance;
}

foreach my $engine (@engines) {
    note "Testing against $engine engine";

    $test_flags = {};

    #This will hijack lwp requests to localhost:3000 and send them to our dancer app
    LWP::Protocol::PSGI->register(get_app_for_engine($engine)); #if I set to hijack a particular <host:port> the connection is refused.

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar({file => "$tempdir/.cookies.$engine.txt"});

    my $r = $ua->get("http://localhost:3000/set_session");
    is $r->content, "ok", "set_session ran ok";

    #we verify whether the hooks were called correctly.
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

    $r = $ua->get("http://localhost:3000/get_session");
    is $r->content, "ok", "get_session ran ok";

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

    $r = $ua->get("http://localhost:3000/destroy_session");
    is $r->content, "ok", "destroy_session ran ok";

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

    File::Temp::cleanup();
}

done_testing;
