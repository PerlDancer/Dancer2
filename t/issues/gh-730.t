use strict;
use warnings;
use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    get '/' => sub { request->is_behind_proxy };
}

my $app = App->to_app;
isa_ok( $app, 'CODE' );

my $test = Plack::Test->create($app);

subtest 'Runner config' => sub {
    plan tests => 5;

    is(
        Dancer2->runner->config->{'behind_proxy'},
        0,
        'No default behind_proxy',
    );

    is(
        scalar @{ Dancer2->runner->apps },
        1,
        'Single app registered',
    );

    isa_ok(
        Dancer2->runner->apps->[0],
        'Dancer2::Core::App',
        'Correct app registered',
    );

    is(
        Dancer2->runner->apps->[0]->setting('behind_proxy'),
        0,
        'behind_proxy not defined by default in an app',
    );

    Dancer2->runner->apps->[0]->config->{'behind_proxy'} = 1;

    is(
        Dancer2->runner->apps->[0]->setting('behind_proxy'),
        1,
        'Set behind_proxy locally in the app to one',
    );

};

subtest 'Using App-level settings' => sub {
    plan tests => 3;

    is(
        Dancer2->runner->config->{'behind_proxy'},
        0,
        'Runner\'s behind_proxy is still the default',
    );

    my $res = $test->request( GET '/' );
    is( $res->code,    200, '[GET /] Correct code'         );
    is( $res->content, '1', '[GET /] Local value achieved' );
};

