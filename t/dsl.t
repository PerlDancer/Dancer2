use Test::More import => ['!pass'];

use strict;
use warnings;
use LWP::UserAgent;

eval "use Test::TCP";
plan skip_all => "need Test::TCP" if $@;

use Dancer::Core::Server::Standalone;

my @tests = (
   $] >= 5.010  ?
     [ [get => '/usr/delete/234'],
       [ 200, [], [join(':', sort (qw'class usr action delete id 234'))] ] ] :
             (),


    [
     [ get => '/' ],
     [ 200, [ 'Content-Type' => 'text/html' ], ['t::lib::TestApp'] ]
    ],
    [
     [ get => '/mime/f' ],
     [ 200, [ ], ['text/foo'] ]
    ],
    [
     [ get => '/mime/foo' ],
     [ 200, [ ], ['text/foo'] ]
    ],
    [
     [ get => '/mime/something' ],
     [ 200, [ ], ['text/bar'] ]
    ],
    [
     [ get => '/haltme' ],
     [ 200, [ ], ['t::lib::TestApp'] ]
    ],
    [
     [ get => '/content_type/svg' ],
     [ 200, [ 'Content-Type' => 'image/svg+xml' ], ['1'] ]
    ],
    [
     [ get => '/content_type/f' ],
     [ 200, [ 'Content-Type' => 'text/foo' ], ['1'] ]
    ],
    [
     [ get => '/rewrite_me' ],
     [ 200, [ ], ['rewritten!'] ]
    ],
    [
     [ post => '/dirname' ],
     [ 200, [ ], ['/etc'] ]
    ],
    [
     [ get => '/user/sukria/home' ],
     [ 200, [ ], ['hello sukria'] ]
    ],
    [
     [ get => '/config' ],
     [ 200, [ ], ['1 1 and 42'] ]
    ],
    [
     [ get => '/header/X-Test/42' ],
     [ 200, [ 'X-Test' => 42 ], ['1'] ]
    ],
    [
     [ get => '/header/X-Test/42/21' ],
     [ 200, [ 'X-Test' => '42, 21' ], ['1'] ]
    ],
    [
     [ get => '/header_twice/X-Test/42/21' ],
     [ 200, [ 'X-Test' => '21' ], ['1'] ]
    ],
    [
     [ get => '/booleans' ],
     [ 200, [ ], ['1:0'] ]
    ],
    [
     [ get => '/any' ],
     [ 200, [ ], ['Called with method GET'] ]
    ],
    [
     [ post => '/any' ],
     [ 200, [ ], ['Called with method POST'] ]
    ],
    [
     [ head => '/any' ],
     [ 200, [ ], [''] ]
    ],
    [
     [ get => '/prefix/bar' ],
     [ 200, [ ], ['/prefix/bar'] ]
    ],
    [
     [ get => '/prefix/prefix1/bar' ],
     [ 200, [ ], ['/prefix/prefix1/bar'] ]
    ],
    # - # FIXME : this is not supported yet, and wasnt neither in dancer 1
    #             branch topic/prefix_nightmare has a fix for it
    #[
    #[ get => '/prefix/prefix2/foo' ],
    #[ 200, [ ], ['/prefix/prefix2/foo'] ]
    #],
);

test_tcp(
    client => sub {
        my $port = shift;

        for my $t (@tests) {
            my $req      = $t->[0];
            my $expected = $t->[1];

            # Using this approach it is not possible to test get/put
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
