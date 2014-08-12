#!perl

use strict;
use warnings;

use File::Spec;
use File::Basename 'dirname';
use Test::More tests => 34;
use Plack::Test;
use HTTP::Request::Common;

my $views = File::Spec->rel2abs(
    File::Spec->catfile( dirname(__FILE__), 'views' )
);

my %called_hooks = ();
my $hook_name    = 'engine.template.before_render';

{
    package App1;
    use Dancer2;

    set views => $views;

    hook before => sub { $called_hooks{'App1'}++ };

    hook before_template => sub {
        my $tokens = shift;
        ::isa_ok( $tokens, 'HASH', '[App1] Tokens are a hash' );

        my $app = app;
        ::isa_ok( $app, 'Dancer2::Core::App', 'Got app object inside App1' );
        ::is(
            scalar @{ $app->template_engine->hooks->{$hook_name} },
            0,
            'App1 only has no before_template hook until we set it',
        );

        $tokens->{'myname'} = 'App1';
        $called_hooks{'App1'}++;
    };

    get '/' => sub {
        template beforetemplate => { it => 'App1' }, { layout => undef };
    };
}

{
    package App2;
    use Dancer2;

    set views => $views;

    hook before => sub { $called_hooks{'App2'}++ };

    hook before_template => sub {
        my $tokens = shift;
        ::isa_ok( $tokens, 'HASH', '[App2] Tokens are a hash' );

        my $app = app;
        ::isa_ok( $app, 'Dancer2::Core::App', 'Got app object inside App2' );
        ::is(
            scalar @{ $app->template_engine->hooks->{$hook_name} },
            0,
            'App2 only has no before_template hook until we set it',
        );

        $tokens->{'myname'} = 'App2';
        $called_hooks{'App2'}++;
    };

    get '/' => sub {
        template beforetemplate => { it => 'App2' }, { layout => undef };
    };
}

note 'Check App1 only calls first hook, not both'; {
    # clear
    %called_hooks = ();

    my $app = App1->psgi_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/' );

        is( $res->code, 200, '[GET /] Successful' );

        is(
            $res->content,
            "App is App1, again, it is App1\n",
            '[GET /] Correct content',
        );

        is_deeply(
            \%called_hooks,
            { App1 => 2 },
            'Only App1\'s before_template hook was called',
        );
    };
}

note 'Check App2 only calls second hook, not both'; {
    # clear
    %called_hooks = ();

    my $app = App2->psgi_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/' );

        is( $res->code, 200, '[GET /] Successful' );

        is(
            $res->content,
            "App is App2, again, it is App2\n",
            '[GET /] Correct content',
        );

        is_deeply(
            \%called_hooks,
            { App2 => 2 },
            'Only App2\'s before_template hook was called',
        );
    };
}

note 'Check both apps only call the first hook, not both'; {
    # clear
    %called_hooks = ();

    my $app = Dancer2->psgi_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/' );

        is( $res->code, 200, '[GET /] Successful' );

        is(
            $res->content,
            "App is App1, again, it is App1\n",
            '[GET /] Correct content',
        );

        is_deeply(
            \%called_hooks,
            { App1 => 2 },
            'Only App1\'s before_template hook was called (full PSGI app)',
        );
    };
}

note 'Check both apps only call the second hook, not both'; {
    # clear
    %called_hooks = ();

    my $app = App2->psgi_app;
    isa_ok( $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/' );

        is( $res->code, 200, '[GET /] Successful' );

        is(
            $res->content,
            "App is App2, again, it is App2\n",
            '[GET /] Correct content',
        );

        is_deeply(
            \%called_hooks,
            { App2 => 2 },
            'Only App2\'s before_template hook was called (full PSGI app)',
        );
    };
}

