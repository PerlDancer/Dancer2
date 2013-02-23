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

subtest 'hooks in plugins' => sub {
    my $counter = 0;

    {
        use Dancer2;
        use t::lib::Hookee;

        hook 'third_hook' => sub {
            var(hook => 'third hook');
        };

        hook 'start_hookee' => sub {
            'hook for plugin';
        };

        get '/hook_with_var' => sub {
            some_other();
            is var('hook') => 'third hook', "Vars preserved from hooks";
        };

        get '/hooks_plugin' => sub {
            $counter++;
            some_keyword();
        };

    }

    is $counter, 0, "the hook has not been executed";
    my $r = dancer_response(GET => '/hooks_plugin');
    is($r->content, 'hook for plugin', '... route is rendered');
    is $counter, 1, "... and the hook has been executed exactly once";

    dancer_response(GET => '/hook_with_var');
};


done_testing;
