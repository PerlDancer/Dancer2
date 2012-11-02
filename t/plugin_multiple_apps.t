# plugin_multiple_apps.t

use strict;
use warnings;
use Test::More;

{
    package App;
    use Dancer;

    use t::lib::SubApp1;
    use t::lib::SubApp2;

}

use Dancer::Test 'App', 't::lib::SubApp1', 't::lib::SubApp2';

# make sure both apps works as epxected
response_content_is '/subapp1', 1;
response_content_is '/subapp2', 2;

done_testing;

