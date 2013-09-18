use Test::More;
use strict;
use warnings;
use Encode;
use utf8;

use Test::TCP 1.13;
use HTTP::Headers;
use HTTP::Request::Common;
use LWP::UserAgent;
use Net::EmptyPort qw(empty_port);

plan tests => 9;

# Find an empty port BEFORE importing Dancer2
my $port;
BEGIN { $port = empty_port }

Test::TCP::test_tcp(
    port => $port,
    client => sub {
        my $port = shift;
        my $ua   = LWP::UserAgent->new;
        my $req  = HTTP::Request::Common::POST(
            "http://127.0.0.1:$port/name",
            [ name => 'vasya' ]
        );
        my $res = $ua->request($req);

        is $res->content_type, 'text/html';
        ok $res->content_type_charset
          ;    # we always have charset if the setting is set
        is $res->content, 'Your name: vasya';

        $req = HTTP::Request::Common::GET("http://127.0.0.1:$port/unicode");
        $res = $ua->request($req);

        is $res->content_type,         'text/html';
        is $res->content_type_charset, 'UTF-8';
        is $res->content, Encode::encode( 'utf-8', "cyrillic shcha \x{0429}" );

        $req = HTTP::Request::Common::GET("http://127.0.0.1:$port/symbols");
        $res = $ua->request($req);
        is $res->content_type,         'text/html';
        is $res->content_type_charset, 'UTF-8';
        is $res->content,
          Encode::encode( 'utf-8', "⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );

    },
    server => sub {
        use Dancer2 port => $port;

        get '/name/:name' => sub {
            "Your name: " . params->{name};
        };

        post '/name' => sub {
            "Your name: " . params->{name};
        };

        get '/unicode' => sub {
            "cyrillic shcha \x{0429}",;
        };

        get '/symbols' => sub {
            '⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙';
        };

        set charset => 'utf-8';

        start;
    },
);
