use strict;
use warnings;
use lib 't/plugin2/app_dsl_cb/lib';
use Test::More 'tests' => 4;
use Plack::Test;
use HTTP::Request::Common 'GET';
use App with => { show_errors => 1 };
use Test::Fatal 'exception';

my $app = App->to_app;
my $test = Plack::Test->create($app);

my $res;
is(
    exception { $res = $test->request( GET '/' ) },
    undef,
    'Did not crash',
);

is( $res->content, 'GET DONE', 'Ran successfully' );
