use strict;
use warnings;
use Test::More import => ['!pass'];

BEGIN {
    use Dancer;
    load_app 't::lib::TestApp', prefix => '/test';
}

is( t::lib::TestApp->dancer_app->name, 't::lib::TestApp' );

use Dancer::Test 't::lib::TestApp';

response_status_is([GET => '/'], 404, 
    'route / is not found (prefix set)');

response_content_is([GET => '/test'], 't::lib::TestApp',
    'route /test works');

done_testing;
