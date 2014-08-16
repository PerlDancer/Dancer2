use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;
use JSON;

subtest 'global and route keywords' => sub {
    {
        use Dancer2;
        use t::lib::FooPlugin;

        sub location {'/tmp'}

        get '/' => sub {
            foo_wrap_request->env->{'PATH_INFO'};
        };

        get '/app' => sub { app->name };

        get '/plugin_setting' => sub { to_json(p_config) };

        foo_route;
    }

    my $app = Dancer2->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is(
            $cb->( GET '/' )->content,
            '/',
            'route defined by a plugin',
        );

        is(
            $cb->( GET '/foo' )->content,
            'foo',
            'DSL keyword wrapped by a plugin',
        );

        is(
            $cb->( GET '/plugin_setting' )->content,
            encode_json( { plugin => "42" } ),
            'plugin_setting returned the expected config'
        );

        is(
            $cb->( GET '/app' )->content,
            'main',
            'app name is correct',
        );
    };
};

subtest 'plugin old syntax' => sub {
    {
        use Dancer2;
        use t::lib::DancerPlugin;

        around_get;
    }

    my $app = Dancer2->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is(
            $cb->( GET '/foo/plugin' )->content,
            'foo plugin',
            'foo plugin',
        );
    };
};

subtest caller_dsl => sub {
    {
        use Dancer2;
        use t::lib::DancerPlugin;
    }

    my $app = Dancer2->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is(
            $cb->( GET '/sitemap' )->content,
            '^\/$, ^\/app$, ^\/foo$, ^\/foo\/plugin$, ^\/plugin_setting$, ^\/sitemap$',
            'Correct content',
        );
    };
};

subtest 'hooks in plugins' => sub {
    my $counter = 0;

    {
        use Dancer2;
        use t::lib::Hookee;

        hook 'third_hook' => sub {
            var( hook => 'third hook' );
        };

        hook 'start_hookee' => sub {
            'this is the start hook';
        };

        get '/hook_with_var' => sub {
            some_other(); # executes 'third_hook'
            is var('hook') => 'third hook', "Vars preserved from hooks";
        };

        get '/hooks_plugin' => sub {
            $counter++;
            some_keyword(); # executes 'start_hookee'
            'hook for plugin';
        };

        get '/hook_returns_stuff' => sub {
            some_keyword(); # executes 'start_hookee'
        };

    }

    my $app = Dancer2->psgi_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        is( $counter, 0, 'the hook has not been executed' );

        is(
            $cb->( GET '/hooks_plugin' )->content,
            'hook for plugin',
            '... route is rendered',
        );

        is( $counter, 1, '... and the hook has been executed exactly once' );

        is(
            $cb->( GET '/hook_returns_stuff' )->content,
            '',
            '... hook does not influence rendered content by return value',
        );

        # call the route that has an additional test
        $cb->( GET '/hook_with_var' );
    };
};


done_testing;
