use strict;
use warnings;
use Test::More import => ['!pass'];
use Carp 'croak';

use Dancer2;
use Dancer2::Core::App;
use Dancer2::Core::Route;
use Dancer2::Core::Dispatcher;
use Dancer2::Core::Hook;
use Dancer2::Core::Response;

set logger => 'Null';

# init our test fixture
my $buffer = {};
my $app = Dancer2::Core::App->new( name => 'main' );

$app->setting( logger      => engine('logger') );
$app->setting( show_errors => 1 );

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
    code   => sub { Fail->fail },
);

# A chain of two route for /user/$foo
$app->add_route(
    method => 'get',
    regexp => '/user/:name',
    code   => sub {
        my $app = shift;
        $buffer->{user} = $app->request->params->{'name'};
        $app->response->has_passed(1);
    },
);

$app->add_route(
    method => 'get',
    regexp => '/user/*?',
    code   => sub {
        my $app = shift;
        "Hello " . $app->request->params->{'name'};
    },
);

# a route with a 204 response
$app->add_route(
    method => 'get',
    regexp => '/twoohfour',
    code   => sub {
        my $app = shift;
        $app->response->status(204);
        "This content should be removed";
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
                'Content-Type'   => 'text/html; charset=UTF-8',
                'Server'         => "Perl Dancer2 " . Dancer2->VERSION,
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
                'Content-Type'   => 'text/html; charset=UTF-8',
                'Server'         => "Perl Dancer2 " . Dancer2->VERSION,
            ],
            ["Hello Johnny"]
        ]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/twoohfour',
        },
        expected => [
            204,
            [   'Content-Type'   => 'text/html; charset=UTF-8',
                'Server'         => "Perl Dancer2 " . Dancer2->VERSION,
            ],
            []
        ]
    },
    {   env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/haltme',
        },
        expected => [
            302,
            [   'Location'       => 'http://perldancer.org',
                'Content-Length' => '305',
                'Content-Type'   => 'text/html; charset=utf-8',
                'Server'         => "Perl Dancer2 " . Dancer2->VERSION,
            ],
            qr/This item has moved/
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
    Dancer2::Core::Hook->new(
        name => 'before',
        code => sub {
            my $app = shift;
            if ( $app->request->path_info eq '/haltme' ) {
                $app->response->header( Location => 'http://perldancer.org' );
                $app->response->status(302);
                $app->response->is_halted(1);
            }
        },
    )
);

my $was_in_second_filter = 0;
$app->add_hook(
    Dancer2::Core::Hook->new(
        name => 'before',
        code => sub {
            my $app = shift;
            if ( $app->request->path_info eq '/haltme' ) {
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

plan tests => 16;

my $dispatcher = Dancer2::Core::Dispatcher->new( apps => [$app] );
my $counter = 0;
foreach my $test (@tests) {
    my $env      = $test->{env};
    my $expected = $test->{expected};
    my $path     = $env->{'PATH_INFO'};

    my $resp = $dispatcher->dispatch($env);

    is( $resp->[0], $expected->[0], "[$path] Return code ok" );

    my %got_headers = @{ $resp->[1] };
    my %exp_headers = @{ $expected->[1] };
    is_deeply( \%got_headers, \%exp_headers, "[$path] Correct headers" );

    if ( ref( $expected->[2] ) eq "Regexp" ) {
        like $resp->[2][0] => $expected->[2], "[$path] Contents ok. (test $counter)";
    }
    else {
        is_deeply $resp->[2] => $expected->[2], "[$path] Contents ok. (test $counter)";
    }
    $counter++;
}

foreach my $test (
    {   env => {
            REQUEST_METHOD    => 'GET',
            PATH_INFO         => '/error',
            'psgi.uri_scheme' => 'http',
            SERVER_NAME       => 'localhost',
            SERVER_PORT       => 5000,
            SERVER_PROTOCOL   => 'HTTP/1.1',
        },
        expected => [
            500,
            [ 'Content-Length', "Content-Type", 'text/html' ],
            qr!Internal Server Error.*Can&#39;t locate object method &quot;fail&quot; via package &quot;Fail&quot; \(perhaps you forgot to load &quot;Fail&quot;\?\) at t[\\/]dispatcher\.t line \d+\.!s
        ]
    }
  )
{
    my $env      = $test->{env};
    my $expected = $test->{expected};

    my $psgi_response = $dispatcher->dispatch($env);
    my $resp          = Dancer2::Core::Response->new(
        status  => $psgi_response->[0],
        headers => $psgi_response->[1],
        content => $psgi_response->[2][0],
    );

    is $resp->status => $expected->[0], "Return code ok.";
    ok( $resp->header('Content-Length') >= 140, "Length ok." );
    like $resp->content, $expected->[2], "contents ok";
}


is $was_in_second_filter, 0, "didn't enter the second filter, because of halt";
