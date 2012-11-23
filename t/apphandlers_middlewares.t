use strict;
use warnings;
use Test::More;
use Dancer 2.0;
use LWP::UserAgent;
use File::Spec;
use lib File::Spec->catdir('t', 'lib');
use Test::TCP;

BEGIN {
    eval { require 'Plack/Request.pm' };
    plan skip_all => "Plack::Request is needed to run this test"
      if $@;
    Plack::Request->import();

    eval { require 'Plack/Loader.pm' };
    Plack::Loader->import();
}

my $confs = [[[['Runtime']]]];

foreach my $c (@$confs) {
    my $server = Test::TCP->new(
        code => sub {
            my $port = shift;

            use TestApp;

            set(environment       => 'production',
                apphandler        => 'PSGI',
                port              => $port,
                startup_info      => 0,
                plack_middlewares => $c->[0]
            );
            Plack::Loader->auto(port => $port)
              ->run(Dancer->runner->server->psgi_app);
        },
    );

#client
    my $port = $server->port;
    my $ua   = LWP::UserAgent->new;

    my $req = HTTP::Request->new(GET => "http://localhost:$port/");
    my $res = $ua->request($req);
    ok $res;
    my $headers = $res->headers;
    print $res->headers_as_string . "\n";
    ok $res->header('X-Runtime');
}

done_testing;
