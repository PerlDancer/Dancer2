use strict;
use warnings;
use lib 't/issues/gh-1226/lib';

use Test::More 'tests' => 4 + 9;
use Test::Fatal qw<exception>;
use Plack::Test ();
use Module::Runtime qw<require_module>;
use HTTP::Request::Common qw<GET>;

my $app;
is(
    exception {
        require_module('App');
        $app = App->to_app;
    },
    undef,
    'No exception when creating new app',
);

isa_ok( $app, 'CODE' );

my $test     = Plack::Test->create($app);
my $response = $test->request( GET '/' );
is( $response->code,    200,  'Correct response code' );
is( $response->content, 'OK', 'Correct response content' );
