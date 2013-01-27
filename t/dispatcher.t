use strict;
use warnings;
use Test::More import => ['!pass'];
use Carp 'croak';

use Dancer (qw':tests');
use Dancer::Test;
use Dancer::Core::App;
use Dancer::Core::Route;
use Dancer::Core::Dispatcher;
use Dancer::Core::Hook;

set logger => 'Null';

# init our test fixture
my $buffer = {};
my $app = Dancer::Core::App->new(name => 'main');

$app->setting(logger => engine('logger'));

# a simple / route
$app->add_route(
    method => 'get',
    regexp => '/',
    code   => sub {"home"},
);

# an error route
$app->add_route(
    method => 'get',
    regexp => '/error',
    code   => sub { Fail->fail; },
);

# A chain of two route for /user/$foo
$app->add_route(
    method => 'get',
    regexp => '/user/:name',
    code   => sub {
        my $ctx = shift;
        $buffer->{user} = $ctx->request->params->{'name'};
        $ctx->response->has_passed(1);
    },
);

$app->add_route(
    method => 'get',
    regexp => '/user/*?',
    code   => sub {
        my $ctx = shift;
        "Hello " . $ctx->request->params->{'name'};
    },
);

# the tests
my @tests = (
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/',
        },
        expected => [
            200,
            [   'Content-Length' => 4,
                'Content-Type'   => 'text/html; charset=UTF-8'
            ],
            ["home"]
        ]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/user/Johnny',
        },
        expected => [
            200,
            [   'Content-Length' => 12,
                'Content-Type'   => 'text/html; charset=UTF-8'
            ],
            ["Hello Johnny"]
        ]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/haltme',
        },
        expected => [
            302,
            [   'Location'       => 'http://perldancer.org',
                'Content-Length' => '0',
                'Content-Type'   => 'text/html',
            ],
            ['']
        ]
    },

# NOT SUPPORTED YET
#    {   env => {
#            REQUEST_METHOD => 'GET',
#            PATH_INFO      => '/admin',
#        },
#        expected => [200, [], ["home"]]
#    },


);

# simulates a redirect with halt
$app->add_hook(
    Dancer::Core::Hook->new(
        name => 'before',
        code => sub {
            my $ctx = shift;
            if ($ctx->request->path_info eq '/haltme') {
                $ctx->response->header(Location => 'http://perldancer.org');
                $ctx->response->status(302);
                $ctx->response->is_halted(1);
            }
        },
    )
);

my $was_in_second_filter = 0;
$app->add_hook(
    Dancer::Core::Hook->new(
        name => 'before',
        code => sub {
            my $ctx = shift;
            if ($ctx->request->path_info eq '/haltme') {
                $was_in_second_filter =
                  1;   # should not happen because first filter halted the flow
            }
        },
    )
);

$app->add_route(
    method => 'get',
    regexp => '/haltme',
    code   => sub {"should not get there"},
);
$app->compile_hooks;

plan tests => 13;

my $dispatcher = Dancer::Core::Dispatcher->new(apps => [$app]);
my $counter = 0;
foreach my $test (@tests) {
    my $env      = $test->{env};
    my $expected = $test->{expected};

    my $resp = $dispatcher->dispatch($env)->to_psgi;

    is $resp->[0] => $expected->[0], "Return code ok.";

    ok(Dancer::Test::_include_in_headers($resp->[1], $expected->[1]),
        "expected headers are there");

    if (ref($expected->[2]) eq "Regexp") {
        like $resp->[2][0] => $expected->[2], "Contents ok. (test $counter)";
    }
    else {
        is_deeply $resp->[2] => $expected->[2], "Contents ok. (test $counter)";
    }
    $counter++;
}

foreach my $test (
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/error',
        },
        expected => [
            500,
            ['Content-Length', "Content-Type", 'text/plain'],
            qr{^Internal Server Error\n\nCan't locate object method "fail" via package "Fail" \(perhaps you forgot to load "Fail"\?\) at t/dispatcher\.t line \d+.*$}s
        ]
    }
  )
{
    my $env      = $test->{env};
    my $expected = $test->{expected};

    my $resp = $dispatcher->dispatch($env);

    is $resp->status => $expected->[0], "Return code ok.";
    ok($resp->header('Content-Length') >= 140, "Length ok.");
    like $resp->content, $expected->[2], "contents ok";
}


is $was_in_second_filter, 0, "didnt enter the second filter, because of halt";
