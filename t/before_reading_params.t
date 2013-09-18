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
        my $res = $ua->get("http://127.0.0.1:$port/readthis/some");
        ok($res->is_success);
        is($res->content, 'some');
    },
    server => sub {
        my $port = shift;
        use Dancer2;

        hook before => sub {
            my $context = shift;
            my $p = $context->request->params->{string};
            $context->vars->{test} = $p;
        };

        get '/readthis/:string' => sub {
            return vars->{test};
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
