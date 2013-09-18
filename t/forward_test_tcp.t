use strict;
use warnings;
use Test::More;
use Test::TCP;
use LWP::UserAgent;
use Net::EmptyPort qw(empty_port);

# Find an empty port BEFORE importing Dancer2
my $port;
BEGIN { $port = empty_port }

test_tcp(
    port   => $port,
    server => sub {
        use Dancer2 port => $port, startup_info => 0;
        get '/'          => sub {
            'home:' . join( ',', params );
        };
        get '/bounce/' => sub {
            return forward '/';
        };
        get '/bounce/:withparams/' => sub {
            return forward '/';
        };
        get '/bounce2/adding_params/' => sub {
            return forward '/', { withparams => 'foo' };
        };
        post '/simple_post_route/' => sub {
            'post:' . join( ',', params );
        };
        get '/go_to_post/' => sub {
            return forward '/simple_post_route/', { foo => 'bar' },
              { method => 'post' };
        };
        post '/'        => sub {'post-home'};
        post '/bounce/' => sub { forward('/') };

        start;
    },
    client => sub {
        my ( $port, $server_pid ) = @_;
        my $ua  = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/");
        is $res->code      => 200;
        like $res->content => qr/home:/;

        $res = $ua->get("http://127.0.0.1:$port/bounce/");
        is $res->code      => 200;
        like $res->content => qr/home:/;

        $res = $ua->get("http://127.0.0.1:$port/bounce/thesethings/");
        is $res->code    => 200;
        is $res->content => 'home:withparams,thesethings';

        $res = $ua->get("http://127.0.0.1:$port/bounce2/adding_params/");
        is $res->code    => 200;
        is $res->content => 'home:withparams,foo';

        $res = $ua->get("http://127.0.0.1:$port/go_to_post/");
        is $res->code    => 200;
        is $res->content => 'post:foo,bar';

        $res = $ua->get("http://127.0.0.1:$port/bounce/");
        is $res->header('Content-Length') => 5;
        is $res->header('Content-Type')   => 'text/html; charset=UTF-8';
        is $res->header('Server')         => "Perl Dancer2 $Dancer2::VERSION";

        $res = $ua->post("http://127.0.0.1:$port/");
        is $res->code    => 200;
        is $res->content => 'post-home';

        $res = $ua->post("http://127.0.0.1:$port/bounce/");
        is $res->code                     => 200;
        is $res->content                  => 'post-home';
        is $res->header('Content-Length') => 9;
        is $res->header('Content-Type')   => 'text/html; charset=UTF-8';
        is $res->header('Server')         => "Perl Dancer2 $Dancer2::VERSION";
    }
);

done_testing;
