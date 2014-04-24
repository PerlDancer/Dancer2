use Test::More;
use strict;
use warnings;
use Encode;
use utf8;

use Test::TCP 1.13;
use HTTP::Headers;
use HTTP::Request;
use LWP::UserAgent;

plan tests => 7;

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;
        my $ua   = LWP::UserAgent->new;
        # Ensure the standalone standaloneerver responds to all the
        # HTTP methods the DSL supports
        for my $method ( qw/HEAD GET PUT POST DELETE OPTIONS PATCH/ ) {
            my $req = HTTP::Request->new($method => "http://127.0.0.1:$port/foo");
            my $res = $ua->request($req);
            ok( $res->is_success, "$method return a 200 response");
        }
    },
    server => sub {
        my $port = shift;
        use Dancer2;
        set charset => 'utf-8';

        any '/foo' => sub {
            header "Allow" => "HEAD,GET,PUT,POST,DELETE,OPTIONS,PATCH";
            "foo";
        };

        # we're overiding a RO attribute only for this test!
        Dancer2->runner->{'port'} = $port;
        start;
    },
);
