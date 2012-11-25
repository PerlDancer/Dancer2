use Test::More;
use strict;
use warnings;
use Dancer 2.0; 
use LWP::UserAgent;
use Test::TCP 1.13;
use File::Spec;
use lib File::Spec->catdir('t', 'lib');
use Plack::Request;
use Plack::Loader;

my $confs = {'/hash' => [['Runtime']],};

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        use TestApp;

        set(environment           => 'production',
            apphandler            => 'PSGI',
            port                  => $port,
            startup_info          => 0,
            plack_middlewares_map => $confs
        );

        Plack::Loader->auto(port => $port)
          ->run(Dancer->runner->server->psgi_app);
    },
);

#client
my $port  = $server->port;
my $ua    = LWP::UserAgent->new;
my @tests = ({path => '/', runtime => 0}, {path => '/hash', runtime => 1});

foreach my $test (@tests) {
    my $req =
      HTTP::Request->new(GET => "http://localhost:$port" . $test->{path});
    my $res = $ua->request($req);
    ok $res, 'result exists for ' . $test->{path};
    print $res->headers_as_string . "\n";
    if ($test->{runtime}) {
        ok $res->header('X-Runtime'), 'X-Runtime where expected';
    }
    else {
        ok !$res->header('X-Runtime'), 'no X-Runtime where expected';
    }
}
done_testing;
