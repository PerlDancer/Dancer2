use strict;
use warnings;

use File::Spec;
use File::Temp 0.22;
use LWP::UserAgent;
use Net::EmptyPort qw(empty_port);
use Test::More;
use Test::TCP 1.13;
use YAML;

# Find an empty port BEFORE importing Dancer2
my $port;
BEGIN { $port = empty_port }

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

Test::TCP::test_tcp(
    port   => $port,
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
        BEGIN {
            use Dancer2 port => $port;
            setting session => 'Simple';
            engine('session')->{'__marker__'} = 1;
        }

        use t::lib::Foo with => { session => engine('session') };

        get '/main' => sub {
            session( 'test' => 42 );
        };

        setting appdir => $tempdir;
        start;
    },
);

done_testing;
