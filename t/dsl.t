use Test::More import => ['!pass'];

use strict;
use warnings;
use LWP::UserAgent;

eval "use Test::TCP";
plan skip_all => "need Test::TCP" if $@;

use Dancer::Core::Server::Standalone;

my @tests = (
    [ 
        [get => '/'], 
        [ 
            200, 
            [], 
            ['t::lib::TestApp'] 
        ]
    ],
    [ 
        [get => '/haltme'],
        [
            200, 
            [ ], 
            ['t::lib::TestApp'] 
        ]
    ],
    [ 
        [post => '/dirname'],
        [
            200, 
            [ ], 
            ['/etc'] 
        ]
    ],
    [ 
        [get => '/user/sukria/home'],
        [
            200, 
            [ ], 
            ['hello sukria'] 
        ]
    ],
    [ 
        [get => '/config'],
        [
            200, 
            [ ], 
            ['1 1'] 
        ]
    ],
    [ 
        [get => '/header/X-Test/42'],
        [
            200, 
            [ 'X-Test' => 42 ], 
            ['1'] 
        ]
    ],
    [
        [get => '/booleans'],
        [
            200,
            [ ],
            ['1:0']
        ]
    ],
);

test_tcp(
    client => sub {
        my $port = shift;

        for my $t (@tests) {
            my $req      = $t->[0];
            my $expected = $t->[1];

            my $method = $req->[0];
            my $path   = $req->[1];
            my $ua     = LWP::UserAgent->new;
            my $res    = $ua->$method("http://localhost:${port}${path}");

            is $res->code, $expected->[0], 
                "status is ok for $method $path";
            is $res->content, $expected->[2][0],
              "content is ok for $method $path";

            # headers
            my $headers = $expected->[1];
            for (my $i = 0; $i < scalar(@$headers); $i += 2) {
                my $header = $headers->[$i];
                my $value  = $headers->[$i + 1];
                is $res->header($header), $value,
                  "header $header is $value for $method $path";
            }
        }
    },
    server => sub {
        my $port = shift;

        use Dancer;
        use t::lib::TestApp;
        
        set server_port => $port;
        start;
    },
);


done_testing;
