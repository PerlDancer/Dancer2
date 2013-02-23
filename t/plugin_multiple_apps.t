# plugin_multiple_apps.t

use strict;
use warnings;
use Test::More;

{

    package App;

    BEGIN {
        use Dancer2;
        set session => 'Simple';
    }

    use t::lib::SubApp1 with => {session => engine('session')};

    use t::lib::SubApp2 with => {session => engine('session')};
}

use Dancer2::Test apps => ['App', 't::lib::SubApp1', 't::lib::SubApp2'];

# make sure both apps works as epxected
response_content_is '/subapp1', 1;
response_content_is '/subapp2', 2;

done_testing;

