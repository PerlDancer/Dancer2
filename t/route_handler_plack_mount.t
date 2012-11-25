use strict;
use warnings;
use Test::More;
use Test::TCP 1.13;
use HTTP::Request;
use LWP::UserAgent;
use HTTP::Server::Simple::PSGI;
use Plack::Builder;

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        my $handler = sub {
            use Dancer 2.0;

            set apphandler => 'PSGI', startup_info => 0;
            Dancer->runner->server->port($port);

            get '/foo' => sub { request->path_info };

            my $env = shift;

            my $app = dancer_app;
            my $dispatcher = Dancer::Core::Dispatcher->new(apps => [$app]);
            $dispatcher->dispatch($env)->to_psgi;
        };

        my $app = builder {
            mount "/mount/test" => $handler;
        };

        my $psgi = HTTP::Server::Simple::PSGI->new($port);
        $psgi->host("127.0.0.1");
        $psgi->app($app);
        $psgi->run;
    },
);

#client
my $port = $server->port;
my $url  = "http://127.0.0.1:$port/mount/test/foo";

my $ua = LWP::UserAgent->new();
my $req = HTTP::Request->new(GET => $url);
ok my $res = $ua->request($req);
ok $res->is_success;
is $res->content, '/foo';

done_testing;
