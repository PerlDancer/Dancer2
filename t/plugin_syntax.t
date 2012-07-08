use strict;
use warnings;
use Test::More import => ['!pass'];
use Dancer::Test;

subtest 'use basic Dancer::Plugin' => sub {
    use_ok 'Dancer::Plugin';
};

subtest 'global and route keywords' => sub {
    {
        use Dancer;
        use t::lib::FooPlugin;

        get '/' => sub {
            foo_wrap_request->env->{'PATH_INFO'};
        };

        get '/app' => sub { app->name };

        foo_route;
    }

    my $r = dancer_response(GET => '/');
    is($r->[2][0], '/', 'route defined by a plugin');

    $r = dancer_response(GET => '/foo');
    is($r->[2][0], 'foo', 'DSL keyword wrapped by a plugin');

    $r = dancer_response(GET => '/app');
    is($r->[2][0], 'main', 'app name is correct');
};

subtest 'plugin old syntax' => sub {
    {
        use Dancer;
        use t::lib::Dancer1Plugin;

        around_get;
    }

    my $r = dancer_response GET => '/foo/plugin';
    is $r->[2][0], 'foo plugin';
};

subtest caller_dsl => sub {
     {
        use Dancer;
        use t::lib::Dancer1Plugin;
    }

    my $r = dancer_response GET => '/sitemap';
    is $r->[2][0], '^\/$, ^\/app$, ^\/foo$, ^\/foo\/plugin$, ^\/sitemap$'

};

subtest 'hooks in plugins' => sub {
    my $counter = 0;

    {
        use Dancer;
        use t::lib::Hookee;

        hook 'start_hookee' => sub {
            'hook for plugin';
        };

        get '/hooks_plugin' => sub {
            $counter++;
            some_keyword();
        };

    }

    is $counter, 0, "the hook has not been executed";
    my $r = dancer_response(GET => '/hooks_plugin');
    is($r->[2][0], 'hook for plugin', '... route is rendered');
    is $counter, 1, "... and the hook has been executed exactly once";
};


done_testing;
