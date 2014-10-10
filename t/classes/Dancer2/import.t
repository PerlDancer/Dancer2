#!perl

use strict;
use warnings;

use Test::More tests => 31;
use Test::Fatal;
use Scalar::Util 'refaddr';
use Plack::Test;
use HTTP::Request::Common;

BEGIN {
    require Dancer2;
    can_ok( Dancer2::, 'runner' );
    is( Dancer2::->runner, undef, 'No runner by default' );
}

{
    package App::CreatingRunner;
    use Dancer2;
}

isa_ok( Dancer2->runner, 'Dancer2::Core::Runner', 'Runner created' );
my $runner_refaddr = refaddr( Dancer2->runner );

{
    package App::NotRecreatingRunner;
    use Dancer2;
}

isa_ok( Dancer2->runner, 'Dancer2::Core::Runner', 'Runner created' );
is( refaddr( Dancer2->runner ), $runner_refaddr, 'Runner not recreated' );

{
    {
        package FakeRunner;
        sub psgi_app {
            ::isa_ok( $_[0], 'FakeRunner' );
            ::is( $_[1], 'psgi_param', 'psgi_app calls Runner->psgi_app' );
            return 'Got it';
        }
    }

    local $Dancer2::runner = bless {}, 'FakeRunner';
    ::is(
        Dancer2->psgi_app('psgi_param'),
        'Got it',
        'psgi_app works as expected',
    );
}

{
    package App::ScriptAllowed;
    require Dancer2;

    ::is(
        ::exception { Dancer2->import(':script') },
        undef,
        ':script is allowed',
    );
}

{
    package App::SyntaxAllowed;
    require Dancer2;

    ::is(
        ::exception { Dancer2->import(':syntax') },
        undef,
        ':syntax is allowed',
    );
}

{
    package App::KeyPairOnly;
    require Dancer2;

    ::like(
        ::exception { Dancer2->import('single') },
        qr{^parameters must be key/value pairs},
        'Must import key/value pairs',
    );

    ::like(
        ::exception { Dancer2->import(qw<three items requested>) },
        qr{^parameters must be key/value pairs},
        'Must import key/value pairs',
    );

    ::is(
        ::exception { Dancer2->import( '!unless' ) },
        undef,
        'Must import key/value pairs unless prefixed by !',
    );

    ::is(
        ::exception { Dancer2->import( '!unless', '!prefixed', '!bythis' ) },
        undef,
        'Must import key/value pairs unless prefixed by !',
    );
}

{
    package App::GettingDSL;
    use Dancer2;

    ::can_ok( __PACKAGE__, qw<get post> );
}

{
    package App::GettingSelectiveDSL;
    use Dancer2 '!post';

    # proper way
    ::can_ok( __PACKAGE__, 'get' );

    # checking this would work too
    ::ok( __PACKAGE__->can('get'), 'get imported successfully' );
    ::ok( ! __PACKAGE__->can('post'), 'Can import keywords selectively' );
}

{
    package App::Main;
    use Dancer2;
    get '/main' => sub {1};
}

{
    package App::ComposedToMain;
    use Dancer2 appname => 'App::Main';
    get '/alsomain' => sub {1};
}

{
    my $runner = Dancer2->runner;
    isa_ok( $runner, 'Dancer2::Core::Runner' );
    my $apps = $runner->apps;

    ok( scalar @{$apps} == 10, 'Correct number of Apps created so far' );

    my @names = sort map +( $_->name ), @{$apps};

    # this is the list of all Apps loaded in this test
    is_deeply(
        \@names,
        [qw<
            App::CreatingRunner
            App::GettingDSL
            App::GettingSelectiveDSL
            App::KeyPairOnly
            App::Main
            App::NotRecreatingRunner
            App::ScriptAllowed
            App::StrictAndWarningsAndUTF8
            App::SyntaxAllowed
            App::WithSettingsChanged
        >],
        'All apps accounted for',
    );

    my $app = App::Main->to_app;
    isa_ok( $app, 'CODE' );
    test_psgi $app, sub {
        my $cb = shift;
        is(
            $cb->( GET '/main' )->content,
            1,
            'Got original app response',
        );

        is(
            $cb->( GET '/alsomain' )->content,
            1,
            'Can compose apps with appname',
        );
    };
}

{
    package App::WithSettingsChanged;
    use Dancer2;
}

{
    App::WithSettingsChanged->import( with => { layout => 'mobile' } );

    my ($app) = grep +( $_->name eq 'App::WithSettingsChanged' ),
        @{ Dancer2->runner->{'apps'} };

    ::isa_ok( $app, 'Dancer2::Core::App' );
    ::is(
        $app->template_engine->{'layout'},
        'mobile',
        'Changed settings using with keyword',
    );
}

{
    package NoStrictNoWarningsNoUTF8;
    no strict;
    no warnings;
    no utf8;

    local $@ = undef;

    eval '$var = 30';

    ::is(
        $@,
        '',
        'no strict (control test)',
    );

    local $SIG{'__WARN__'} = sub {
        ::is(
            $_[0],
            undef,
            'no warning (control test)',
        );
    };

    eval 'my $var; my $var;';
}

{
    package App::StrictAndWarningsAndUTF8;
    use Dancer2;

    local $@ = undef;

    local $SIG{'__WARN__'} = sub {
        ::ok(
            $_[0],
            'warnings pragma imported',
        );
    };

    eval '$var = 30;';

    ::like(
        $@,
        qr/^Global symbol/,
        'strict pragma imported',
    );

    eval 'my $var; my $var;';
}

