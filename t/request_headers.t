use strict;
use warnings;
use Test::More;
use LWP::UserAgent;
use Test::TCP 1.13;
use Plack::Request;
use Plack::Loader;

for my $handler (qw/Standalone PSGI/) {
    my $server = Test::TCP->new(
        code => sub {
            my $port = shift;
            use Dancer 2.0;

            set(apphandler   => $handlers[0],
                show_errors  => 1,
                startup_info => 0
            );

            Dancer->runner->server->port($port);

            hook after => sub {
                my $response = shift;
                $response->header('X-Foo', 2);
            };

            get '/req' => sub {
                is(request->header('X-User-Head1'),
                    42, "header X-User-Head1 is ok");
                is(request->header('X-User-Head2'),
                    43, "header X-User-Head2 is ok");
                headers('X-Bar', 3);
                content_type('text/plain');
            };

            if ($handler eq 'PSGI') {
                Plack::Loader->auto(port => $port)
                  ->run(Dancer->runner->server->psgi_app);
            }
            else {
                start;
            }
        },
    );

#client
    my $port = $server->port;
    my $ua   = LWP::UserAgent->new;

    my $request = HTTP::Request->new(GET => "http://127.0.0.1:$port/req");
    $request->header('X-User-Head1' => 42);
    $request->header('X-User-Head2' => 43);

    my $res = $ua->request($request);
    ok($res->is_success, "$handler server responded");
    is($res->header('X-Foo'),        2);
    is($res->header('X-Bar'),        3);
    is($res->header('Content-Type'), 'text/plain');
}

done_testing;
