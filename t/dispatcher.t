use strict;
use warnings;
use Test::More;
use Carp 'croak';

use Dancer::Core::App;
use Dancer::Core::Route;
use Dancer::Core::Dispatcher;
use Dancer::Core::Hook;

# init our test fixture
my $buffer = {};
my $app = Dancer::Core::App->new(name => 'main');

# a simple / route
$app->add_route(
    method => 'get',
    regexp => '/',
    code => sub { "home" },
);

# an error route
$app->add_route (
    method => 'get',
    regexp => '/error',
    code => sub { Fail->fail; },
);

# A chain of two route for /user/$foo 
$app->add_route(
    method => 'get',
    regexp => '/user/:name',
    code => sub {
        my $ctx = shift;
        $buffer->{user} = $ctx->request->params->{'name'};
        $ctx->response->{has_passed} = 1;
    },
);

$app->add_route(
    method => 'get',
    regexp => '/user/*?',
    code => sub {
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
        expected => [200, [], ["home"]]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/user/Johnny',
        },
        expected => [200, [], ["Hello Johnny"]]
    },
    {   env => {
            REQUEST_METHOD => 'POST',
            PATH_INFO      => '/user/Johnny',
        },
        expected => [404, [], ["404 Not Found\n\n/user/Johnny\n"]]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/error',
        },
        expected => [500, [], [qq{Internal Server Error\n\nCan't locate object method "fail" via package "Fail" (perhaps you forgot to load "Fail"?) at t/dispatcher.t line 26.\n\n}]]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/haltme',
        },
        expected => [302, [Location => 'http://perldancer.org'], ['']]
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
$app->add_hook(Dancer::Core::Hook->new(
    name => 'before', 
    code => sub {
        my $ctx = shift;
        if ($ctx->request->path_info eq '/haltme') {
            $ctx->response->{headers} = [Location => 'http://perldancer.org',];
            $ctx->response->{status} = 302;
            $ctx->response->{is_halted} = 1;
        }
      },
));

my $was_in_second_filter = 0;
$app->add_hook(Dancer::Core::Hook->new(
    name => 'before', 
    code => sub {
        my $ctx = shift;
        if ($ctx->request->path_info eq '/haltme') {
            $was_in_second_filter = 1; # should not happen because first filter halted the flow
        }
      },
));

$app->add_route(
    method => 'get',
    regexp => '/haltme',
    code => sub { "should not get there" },
);
$app->compile_hooks;

plan tests => scalar(@tests) + 1;

my $dispatcher = Dancer::Core::Dispatcher->new(apps => [$app]);
foreach my $test (@tests) {
    my $env = $test->{env};
    my $expected = $test->{expected};

    my $resp = $dispatcher->dispatch($env);
    is_deeply $resp, $expected;
}

is $was_in_second_filter, 0, "didnt enter the second filter, because of halt";
