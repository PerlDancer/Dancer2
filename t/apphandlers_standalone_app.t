use strict;
use warnings;
use Test::More;
use Test::TCP 1.13;
use LWP::UserAgent;
use File::Spec;

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

        use Dancer 2.0;
        use lib File::Spec->catdir('t', 'lib');
        use TestApp;
        set(startup_info => 0);
        Dancer->runner->server->port($port);
        start;
    },
);

# client
my $port = $server->port;
my $ua   = LWP::UserAgent->new;

my $res = $ua->get("http://127.0.0.1:$port/env");
like $res->content, qr/PATH_INFO/, 'path info is found in response';

$res = $ua->get("http://127.0.0.1:$port/name/bar");
like $res->content, qr/Your name: bar/, 'name is found on a GET';

$res = $ua->get("http://127.0.0.1:$port/name/baz");
like $res->content, qr/Your name: baz/, 'name is found on a GET';

$res = $ua->post("http://127.0.0.1:$port/name", {name => "xxx"});
like $res->content, qr/Your name: xxx/, 'name is found on a POST';

# we are already skipping under MSWin32 (check plan above)
$res = $ua->get("http://127.0.0.1:$port/issues/499/true");
is $res->content, "OK", 'system true is 0';

$res = $ua->get("http://127.0.0.1:$port/issues/499/false");
is $res->content, "OK", 'system false is not 0';

done_testing;