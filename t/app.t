use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer::Core::App;
use Dancer::Core::Dispatcher;
use Dancer::Core::Hook;
use Dancer::FileUtils;
use File::Spec;
use File::Basename 'dirname';

# our app/dispatcher object
my $app = Dancer::Core::App->new(
    name => 'main',
);
my $dispatcher = Dancer::Core::Dispatcher->new(apps => [$app]);

# first basic tests
isa_ok $app, 'Dancer::Core::App';

# some routes to play with
my @routes = (
    {   method => 'get',
        regexp => '/',
        code   => sub {'/'},
    },
    {   method => 'get',
        regexp => '/blog',
        code   => sub {'/blog'},
    },
);

# testing with and without prefixes
for my $p ('/', '/mywebsite') {
    for my $r (@routes) {
        $app->prefix($p);
        $app->add_route(%$r);
    }
}

is $app->environment, 'development';

my $routes_regexps = $app->routes_regexps_for('get');
is (scalar(@$routes_regexps), 4, "route regexps are OK");

for my $path ('/', '/blog', '/mywebsite', '/mywebsite/blog',) {
    my $env = {
        REQUEST_METHOD => 'GET',
        PATH_INFO => $path };

    my $expected = {
        '/' => '/',
        '/blog' => '/blog',
        '/mywebsite' => '/',
        '/mywebsite/blog' => '/blog',
    };

    my $resp = $dispatcher->dispatch($env)->to_psgi;
    is $resp->[0], 200, 'got a 200';
    is $resp->[2][0], $expected->{$path}, 'got expected route';
}

note "testing lexical prefixes";

# clear the prefix in $app (and by the way, makes sure it works when prefix is
# undef).
$app->prefix(undef);

# nested prefixes bitches!
$app->lexical_prefix(
    '/foo' => sub {
        $app->add_route(
            method => 'get',
            regexp => '/',
            code => sub { '/foo' });

        $app->add_route(
            method => 'get',
            regexp => '/second',
            code => sub { '/foo/second' });

        $app->lexical_prefix('/bar' => sub {
            $app->add_route(
                method => 'get',
                regexp => '/',
                code => sub { '/foo/bar' });
            $app->add_route(
                method => 'get',
                regexp => '/second',
                code => sub { '/foo/bar/second' });
        });
    },
);

# to make sure the lexical prefix did not crash anything
$app->add_route(
    method => 'get',
    regexp => '/root',
    code => sub { '/root' }
);

# make sure a meaningless lexical prefix is ignored
$app->lexical_prefix( '/' => sub {
    $app->add_route(
        method => 'get',
        regexp => '/somewhere',
        code   => sub {'/somewhere'},
    );
});

for my $path ('/foo', '/foo/second', '/foo/bar/second', '/root', '/somewhere') {
    my $env = {
        REQUEST_METHOD => 'GET',
        PATH_INFO => $path,
    };

    my $resp = $dispatcher->dispatch($env)->to_psgi;
    is $resp->[0], 200, 'got a 200';
    is $resp->[2][0], $path, 'got expected route';
}

note "test a failure in the callback of a lexical prefix";
like(
    exception {
        $app->lexical_prefix('/test' => sub { Failure->game_over() });
    },
    qr{Unable to run the callback for prefix '/test': Can't locate object method "game_over" via package "Failure"},
    "caught an exception in the lexical prefix callback",
);

$app->add_hook(Dancer::Core::Hook->new(
    name => 'before',
    code => sub { 1 },
));

$app->add_hook(Dancer::Core::Hook->new(
    name => 'before',
    code => sub { Foo->failure; },
));

$app->compile_hooks;
my $env = {
    REQUEST_METHOD => 'GET',
    PATH_INFO => '/',
};

like(
    exception { my $resp = $dispatcher->dispatch($env)->to_psgi },
    qr{Exception caught in 'core.app.before_request' filter: Hook error: Can't locate object method "failure"},
    'before filter nonexistent method failure',
);

$app->replace_hooks('core.app.before_request', [ sub { 1 } ]);
$app->compile_hooks;
$env = {
    REQUEST_METHOD => 'GET',
    PATH_INFO => '/',
};

is(
    exception { my $resp = $dispatcher->dispatch($env)->to_psgi },
    undef,
    'Successful to_psgi of response',
);

done_testing;
