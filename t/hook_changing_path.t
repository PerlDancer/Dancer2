use strict;
use warnings;
use Test::More;

use Test::TCP;
use LWP::UserAgent;


Test::TCP::test_tcp(
    client => sub {
        my $port = shift;

        #Enter with a language-equipped URL
        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar({file => "cookies.txt"});
        my $res = $ua->get("http://127.0.0.1:$port/prefix/configured");
        ok($res->is_success);
        is($res->content, 'prefix');
    },
    server => sub {
        my $port = shift;
        use Dancer2;

        hook before => sub {
            my $context = shift;
            my $path = $context->request->path_info();
            if($path =~ m/^\/prefix/)
            {
                $path =~ s/^\/prefix//;
                $context->response( $context->request->forward($context, $path, { cut => 'prefix'}, undef));
                $context->response->halt;
            }
        };

        get '/configured' => sub {
            return request->params->{'cut'};
        };      

        set(show_errors  => 1,
            startup_info => 1,
            public => '.',
            environment  => 'development',
            port         => $port,
            logger       => 'console',
            log          => 'debug',
            );

        Dancer2->runner->server->port($port);
        start;
    },
);
done_testing;
