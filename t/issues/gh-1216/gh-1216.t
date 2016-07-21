use strict;
use warnings;
use lib 't/issues/gh-1216/lib';

use Test::More      'tests' => 2;
use Test::Fatal     qw<exception>;
use Module::Runtime qw<require_module>;

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
