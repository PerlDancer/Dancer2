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
is_deeply $app->routes, {}, "routes registry is empty";

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


done_testing;
