use Test::More;
use strict;
use warnings;
use LWP::UserAgent;

use Test::TCP 1.13;
use File::Temp;
use Net::EmptyPort qw(empty_port);

# Find an empty port BEFORE importing Dancer2
my $port;
BEGIN { $port = empty_port }

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

my $server = Test::TCP->new( port => $port, code => sub {
    use Dancer2 port => $port;

    set session => 'Simple';

    get '/set_chained_session' => sub {
        session 'zbr' => 'ugh';
        forward '/set_session';
    };

    get '/set_session' => sub {
        session 'foo' => 'bar';
        forward '/get_session';
    };

    get '/get_session' => sub {
        session 'more' => 'one';
        sprintf("%s:%s:%s", session("more"), session('foo') , session('zbr')||"")
    };

    get '/clear' => sub {
        session "foo" => undef;
        session "zbr" => undef;
        session "more" => undef;
    };

    start;
});

# Client tests against server:
my $ua = LWP::UserAgent->new;
$ua->cookie_jar( { file => "$tempdir/.cookies.txt" } );

my $res = $ua->get("http://127.0.0.1:$port/set_chained_session");
is $res->content, q{one:bar:ugh}, 'Session value preserved after chained forwards';

$res = $ua->get("http://127.0.0.1:$port/get_session");
is $res->content, q{one:bar:ugh}, 'Session values preserved between calls';

$res = $ua->get("http://127.0.0.1:$port/clear");

$res = $ua->get("http://127.0.0.1:$port/set_session");
is $res->content, q{one:bar:}, 'Session value preserved after forward from route';


done_testing;
