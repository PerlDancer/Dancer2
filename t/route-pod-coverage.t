use strict;
use warnings;

use Test::More tests => 2;

use t::lib::TestPod;

use Dancer2::Test apps => ['t::lib::TestPod'];

is_pod_covered ' is pod covered';

my $expected_data = {
    't::lib::TestPod' => {
        has_pod => 1,
        routes  => [['get', '/in_testpod']]
    }
};
my $pod_coverage = route_pod_coverage;
is_deeply($pod_coverage, $expected_data,
    'comparing expected pod data with existing pod data');
