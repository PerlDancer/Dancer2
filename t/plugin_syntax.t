use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;

subtest 'global and route keywords' => sub {
    {
        package App1;
        use Dancer2;
        use lib 't/lib';
        use Dancer2::Plugin::FooPlugin;

        sub location {'/tmp'}

        get '/' => sub {
            foo_wrap_request->env->{'PATH_INFO'};
        };

        get '/app' => sub { app->name };

        get '/plugin_setting' => sub { to_json(p_config) };

        foo_route;
    }

    my $app = App1->to_app;
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
            _normalize($cb->( GET '/plugin_setting' )->content),
            _normalize(encode_json( { plugin => '42' } )),
            'plugin_setting returned the expected config'
        );

        is(
            $cb->( GET '/app' )->content,
            'App1',
            'app name is correct',
        );
    };
};

subtest 'plugin old syntax' => sub {
    {
        package App2;
        use Dancer2;
        use lib 't/lib';
        use Dancer2::Plugin::DancerPlugin;

        around_get;
    }

    my $app = App2->to_app;
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
    my $app = App1->to_app;
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
        package App3;
        use Dancer2;
        use lib 't/lib';
        use Dancer2::Plugin::OnPluginImport;
        use Dancer2::Plugin::Hookee;
        use Dancer2::Plugin::EmptyPlugin;

        hook 'third_hook' => sub {
            var( hook => 'third hook' );
        };

        hook 'start_hookee' => sub {
            'this is the start hook';
        };

        get '/hook_with_var' => sub {
            some_other(); # executes 'third_hook'
            ::is var('hook') => 'third hook', "Vars preserved from hooks";
        };

        get '/hooks_plugin' => sub {
            $counter++;
            some_keyword(); # executes 'start_hookee'
            'hook for plugin';
        };

        get '/hook_returns_stuff' => sub {
            some_keyword(); # executes 'start_hookee'
        };

        get '/on_import' => sub {
            some_import(); # execute 'plugin_import'
        }

    }

    my $app = App3->to_app;
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

        is (
            $cb->( GET '/on_import' )->content,
            Dancer2->VERSION,
            'hooks added by on_plugin_import don\'t stop hooks being added later'
        );
    };
};

sub _normalize {
  my ($json) = @_;

  my $data = decode_json($json);
  foreach (keys %$data) {
    $data->{$_} = $data->{$_} * 1 if ($data->{$_} =~ m/^\d+$/);
  }

  return encode_json($data);
}

done_testing;
