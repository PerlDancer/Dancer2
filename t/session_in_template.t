use strict;
use warnings;
use Test::More;

use YAML;
use Test::TCP 1.13;
use File::Temp 0.22;
use LWP::UserAgent;
use HTTP::Date qw/str2time/;
use File::Spec;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar( { file => "$tempdir/.cookies.txt" } );

        my $res = $ua->get("http://127.0.0.1:$port/");
        ok $res->is_success;
        is $res->content, "session.name \n";

        $res = $ua->get("http://127.0.0.1:$port/set_session/test_name");
        ok $res->is_success;
        is $res->content, "session.name test_name\n";

        $res = $ua->get("http://127.0.0.1:$port/destroy_session");
        ok $res->is_success;
        is $res->content, "session.name \n";

        File::Temp::cleanup();
    },
    server => sub {
        my $port = shift;

        use Dancer2;

        get '/' => sub {
            template 'session_in_template'
        };

        get '/set_session/*' => sub {
            my ($name) = splat;
            session name => $name;
            template 'session_in_template';
        };

        get '/destroy_session' => sub {
            # Need to call the 'session' keyword, so app->setup_session
            # is called and the session attribute in the engines is populated
            my $name = session 'name';
            # Destroying the session should remove the session object from
            # all engines.
            app->destroy_session;
            template 'session_in_template';
        };

        setting appdir => $tempdir;
        setting(
            engines => {
                session => { 'Simple' => { session_dir => 't/sessions' } }
            }
        );
        setting( session => 'Simple' );

        set(show_errors  => 1,
            startup_info => 0,
            environment  => 'production',
            port         => $port
        );

        # we're overiding a RO attribute only for this test!
        Dancer2->runner->{'port'} = $port;
        start;
    },
);
done_testing;
