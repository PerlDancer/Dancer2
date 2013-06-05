use strict;
use warnings;

use Test::More;

use t::lib::TestPod;
use Dancer2::Test apps => ['t::lib::TestPod'];

is_pod_covered 'is pod covered';

my $pod_structure = {
    't::lib::TestPod' => {
        'has_pod' => 1,
        'routes'  => [
            "post /in_testpod/*",
            "post /me:id",
            "get /in_testpod",
            "get /hello",
            "get /me:id"
        ]
    }
};

is_deeply(route_pod_coverage, $pod_structure, 'my pod looks like expected' );

done_testing;
