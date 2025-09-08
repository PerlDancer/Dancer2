use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Dancer2;
use Dancer2::Core::App;
use Dancer2::Core::Dispatcher;
use Dancer2::Core::Hook;
use Dancer2::FileUtils;
use File::Spec;

# our app/dispatcher object
my $app = Dancer2::Core::App->new( name => 'main', );
$app->setting( show_stacktrace => 1 ); # enable show stacktrace
my $dispatcher = Dancer2::Core::Dispatcher->new( apps => [$app] );

# first basic tests
isa_ok $app, 'Dancer2::Core::App';

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
for my $p ( '/', '/mywebsite' ) {
    for my $r (@routes) {
        $app->prefix($p);
        $app->add_route(%$r);
    }
}

is $app->environment, 'development';

my $routes_regexps = $app->routes_regexps_for('get');
is( scalar(@$routes_regexps), 4, "route regexps are OK" );

for my $path ( '/', '/blog', '/mywebsite/', '/mywebsite/blog', ) {
    my $env = {
        REQUEST_METHOD => 'GET',
        PATH_INFO      => $path
    };

    my $expected = {
        '/'               => '/',
        '/blog'           => '/blog',
        '/mywebsite/'     => '/',
        '/mywebsite/blog' => '/blog',
    };

    my $resp = $dispatcher->dispatch($env);
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
            code   => sub {'/foo/'}
        );

        $app->add_route(
            method => 'get',
            regexp => '/second',
            code   => sub {'/foo/second'}
        );

        $app->lexical_prefix(
            '/bar' => sub {
                $app->add_route(
                    method => 'get',
                    regexp => '/',
                    code   => sub {'/foo/bar'}
                );
                $app->add_route(
                    method => 'get',
                    regexp => '/second',
                    code   => sub {'/foo/bar/second'}
                );
            }
        );
    },
);

# to make sure the lexical prefix did not crash anything
$app->add_route(
    method => 'get',
    regexp => '/root',
    code   => sub {'/root'}
);

# make sure a meaningless lexical prefix is ignored
$app->lexical_prefix(
    '/' => sub {
        $app->add_route(
            method => 'get',
            regexp => '/somewhere',
            code   => sub {'/somewhere'},
        );
    }
);

for
  my $path ( '/foo/', '/foo/second', '/foo/bar/second', '/root', '/somewhere' )
{
    my $env = {
        REQUEST_METHOD => 'GET',
        PATH_INFO      => $path,
    };

    my $resp = $dispatcher->dispatch($env);
    is $resp->[0], 200, 'got a 200';
    is $resp->[2][0], $path, 'got expected route';
}

note 'Check to ensure that add_route can override a prefix, even with undef. (gh-1663)';

my @more_routes = (
    {   method => 'get',
        regexp => '/prefix_test',
        code   => sub {'/prefix_test'},
    },
    {   method => 'get',
        regexp => '/prefix_override_test',
        prefix => '/prefixtest2',
        code   => sub {'/prefix_override_test'},
    },
    {   method => 'get',
        regexp => '/noprefix_test',
        code   => sub {'/noprefix_test'},
   prefix => undef,
    },
);
$app->prefix('/prefixtest');

for my $r (@more_routes) {
   $app->add_route(%$r);
}

my $expected_retvals = {
   '/prefix_test' => 404,
   '/prefixtest/prefix_test' => 200,
   '/prefixtest2/prefix_test' => 404,
   '/prefix_override_test' => 404,
   '/prefixtest/prefix_override_test' => 404,
   '/prefixtest2/prefix_override_test' => 200,
   '/noprefix_test' => 200,
   '/prefixtest/noprefix_test' => 404,
   '/prefixtest2/noprefix_test' => 404,
};

my $expected = {
   '/prefix_test' => undef,
   '/prefixtest/prefix_test' => '/prefix_test',
   '/prefixtest2/prefix_test' => undef,
   '/prefix_override_test' => undef,
   '/prefixtest/prefix_override_test' => undef,
   '/prefixtest2/prefix_override_test' => '/prefix_override_test',
   '/noprefix_test' => '/noprefix_test',
   '/prefixtest/noprefix_test' => undef,
   '/prefixtest2/noprefix_test' => undef,
};

for my $path ( sort keys %$expected_retvals ) {
   my $env = {
       SERVER_PORT => 5000,
       SERVER_NAME => 'test.local',
       REQUEST_METHOD => 'GET',
       PATH_INFO      => $path
   };

   my $resp = $dispatcher->dispatch($env);
   is $resp->[0], $expected_retvals->{$path}, "got expected return value on $path";
   next if $expected_retvals->{$path} == 404;
   is $resp->[2][0], $expected->{$path}, 'got expected route';
}

note "test a failure in the callback of a lexical prefix";
like(
    exception {
        $app->lexical_prefix( '/test' => sub { Failure->game_over() } );
    },
    qr{Unable to run the callback for prefix '/test': Can't locate object method "game_over" via package "Failure"},
    "caught an exception in the lexical prefix callback",
);

$app->add_hook(
    Dancer2::Core::Hook->new(
        name => 'before',
        code => sub {1},
    )
);

$app->add_hook(
    Dancer2::Core::Hook->new(
        name => 'before',
        code => sub { Foo->failure; },
    )
);

$app->compile_hooks;
my $env = {
    REQUEST_METHOD => 'GET',
    PATH_INFO      => '/',
};

like(
    $dispatcher->dispatch($env)->[2][0],
    qr/Exception caught in &#39;core.app.before_request&#39; filter: Hook error: Can&#39;t locate object method &quot;failure&quot;/,
    'before filter nonexistent method failure',
);

$app->replace_hook( 'core.app.before_request', [ sub {1} ] );
$app->compile_hooks;
$env = {
    REQUEST_METHOD => 'GET',
    PATH_INFO      => '/',
};

# test duplicate routes when the path is a regex
$app = Dancer2::Core::App->new( name => 'main' );
my $regexp_route = {
    method => 'get', 'regexp' => qr!/(\d+)!, code => sub {1}
};
$app->add_route(%$regexp_route);

# try to get an invalid engine
eval {$app->engine('foo')};
like(
    $@,
    qr/^Engine 'foo' is not supported/,
    "Engine 'foo' does not exist",
);

my $tmpl_engine = $app->engine('template');
ok $tmpl_engine, "Template engine is defined";

ok !$app->has_serializer_engine, "Serializer engine does not exist";

is_deeply(
    $app->_get_config_for_engine('NonExistent'),
    {},
    'Empty configuration for nonexistent engine',
);

# TODO: not such an intelligent check, these ones...
# set configuration for an engine
$app->config->{'engines'}{'template'}{'Tiny'}{'hello'} = 'world';
$app->config->{'engines'}{'template'}{'Some::Other::Template::Namespace'}{'hello'} = 'world';

is_deeply(
    $app->_get_config_for_engine( template => 'Tiny', $app->config ),
    { hello => 'world' },
    '_get_config_for_engine can find the right configuration',
);

is_deeply(
    $app->_get_config_for_engine( template => '+Some::Other::Template::Namespace', $app->config ),
    { hello => 'world' },
    '_get_config_for_engine can find the right configuration',
);

is(
    File::Spec->canonpath( $app->caller ),
    File::Spec->catfile(t => 'app.t'),
    'Correct caller for app',
);

done_testing;
