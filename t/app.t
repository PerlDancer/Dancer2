use strict;
use warnings;
use Test::More;
use Dancer::Core::App;

# mock a request to avoid using Dancer::Request here
{
    package FakeRequest;

    sub method { $_[0]->{method} }
    sub path_info { $_[0]->{path_info} }
    sub new {
        my ($class, %attrs) = @_;
        bless \%attrs, 'FakeRequest';
    }
}

# our app object
my $app = Dancer::Core::App->new(
    name => 'main',
);

# first basic tests
isa_ok $app, 'Dancer::Core::App';

# some routes to play with
my @routes = (
    {   method => 'get',
        regexp => '/',
        code   => sub {'home'},
    },
    {   method => 'get',
        regexp => '/blog',
        code   => sub {'blog'},
    },
);

# testing with and without prefixes
for my $p ('/', '/mywebsite') {
    for my $r (@routes) {
        $app->prefix($p);
        $app->add_route(%$r);
    }
}

my $routes_regexps = $app->routes_regexps_for('get');
is (scalar(@$routes_regexps), 4, "route regexps are OK");

for my $path ('/', '/blog', '/mywebsite', '/mywebsite/blog',) {
    my $req = FakeRequest->new(method => 'get', path_info => $path);

    my $route = $app->find_route_for_request($req);
    isa_ok $route, 'Dancer::Core::Route';

    my $regexp = $route->regexp;
    like $path, qr{$regexp}, "path '$path' matches route '$regexp'";
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
    my $req = FakeRequest->new(method => 'get', path_info => $path);

    my $route = $app->find_route_for_request($req);
    ok(defined($route), "got a route for $path");

    my $regexp = $route->regexp;
    like $path, qr{$regexp}, "path '$path' matches route '$regexp'";
    is $route->execute, $path, 'got expected route';
}

note "test a failure in the callback of a lexical prefix";
eval {
    $app->lexical_prefix('/test' => sub { Failure->game_over() });
};
like $@, qr{Unable to run the callback for prefix '/test': Can't locate object method "game_over" via package "Failure"}, 
    "caught an exception in the lexical prefix callback";

done_testing;
