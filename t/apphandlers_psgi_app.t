use Test::More;
use strict;
use warnings;
use Test::TCP 1.13;
use LWP::UserAgent;
use File::Spec;
use lib File::Spec->catdir('t', 'lib');
use Dancer 2.0;

#skip on Win32?

BEGIN {
    eval { require 'Plack/Request.pm' };
    plan skip_all => "Plack::Request is needed to run this test"
      if $@;
    Plack::Request->import();

    eval { require 'Plack/Loader.pm' };
    Plack::Loader->import();
}

my $server = Test::TCP->new(
    code => sub {
        my $port = shift;

        use TestApp;
        set apphandler => 'PSGI', environment => 'production';
        Plack::Loader->auto(port => $port)
          ->run(Dancer->runner->server->psgi_app);
    },
);

#client
my $port = $server->port;
my $ua   = LWP::UserAgent->new;

my $res = $ua->get("http://127.0.0.1:$port/env");
like $res->content, qr/psgi\.version/, 'content looks good for /env';

$res = $ua->get("http://127.0.0.1:$port/name/bar");
like $res->content, qr/Your name: bar/, 'content looks good for /name/bar';

$res = $ua->get("http://127.0.0.1:$port/name/baz");
like $res->content, qr/Your name: baz/, 'content looks good for /name/baz';

done_testing;
