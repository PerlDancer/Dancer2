# plugin_exports.t

use strict;
use warnings;
use Test::More;

subtest 'with only one app' => sub {
    {
        use Dancer;
        use t::lib::App1;
    }

    use Dancer::Test;

    response_content_is '/app1', 44;
};

done_testing;

