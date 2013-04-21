use strict;
use warnings;
use Test::More import => ['!pass'];
use Dancer2::Test;

subtest 'use basic Dancer2::Plugin' => sub {
    use_ok 'Dancer2::Plugin';
};

subtest 'global and route keywords' => sub {
    {
        use Dancer2;
        use t::lib::FooPlugin;

        get '/' => sub {
            foo_wrap_request->env->{'PATH_INFO'};
        };

        get '/app' => sub { app->name };

        foo_route;
    }

    my $r = dancer_response(GET => '/');
    is($r->content, '/', 'route defined by a plugin');

    $r = dancer_response(GET => '/foo');
    is($r->content, 'foo', 'DSL keyword wrapped by a plugin');

    $r = dancer_response(GET => '/app');
    is($r->content, 'main', 'app name is correct');
};

subtest 'plugin old syntax' => sub {
    {
        use Dancer2;
        use t::lib::DancerPlugin;

        around_get;
    }

    my $r = dancer_response GET => '/foo/plugin';
    is $r->content, 'foo plugin';
};

subtest caller_dsl => sub {
    {
        use Dancer2;
        use t::lib::DancerPlugin;
    }

    my $r = dancer_response GET => '/sitemap';
    is $r->content, '^\/$, ^\/app$, ^\/foo$, ^\/foo\/plugin$, ^\/sitemap$';
};

done_testing;
