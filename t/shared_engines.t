use strict;
use warnings;

use File::Spec;
use File::Temp 0.22;
use LWP::UserAgent;
use Test::More;
use Test::TCP 1.13;
use YAML;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar( { file => "$tempdir/.cookies.txt" } );

        my $res = $ua->get("http://127.0.0.1:$port/main");
        like $res->content, qr{42}, "session is set in main";

        $res = $ua->get("http://127.0.0.1:$port/in_foo");
        like $res->content, qr{42}, "session is set in foo";

        my $engine = t::lib::Foo->dsl->engine('session');
        is $engine->{__marker__}, 1,
          "the session engine in subapp is the same";

        File::Temp::cleanup();
    },
    server => sub {
        my $port = shift;

        BEGIN {
            use Dancer2;
            set session => 'Simple';
            engine('session')->{'__marker__'} = 1;
        }

        use t::lib::Foo with => { session => engine('session') };

        get '/main' => sub {
            session( 'test' => 42 );
        };

        setting appdir => $tempdir;
        # we're overiding a RO attribute only for this test!
        Dancer2->runner->{'port'} = $port;
        start;
    },
);

done_testing;
