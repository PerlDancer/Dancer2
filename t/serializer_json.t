use strict;
use warnings;

use Test::More;

require Dancer2::Serializer::JSON;

my @tests = (
    {   entity  => { a      => 1, b => 2, },
        options => { pretty => 1 },
    },
    {   entity =>
          { c => [ { d => 3, e => { f => 4, g => 'word', } } ], h => 6 },
        options => { pretty => 1 },
    }
);

for my $test (@tests) {
    my $actual =
      Dancer2::Serializer::JSON::to_json( $test->{entity}, $test->{options} );
    my $expected = JSON::to_json( $test->{entity}, $test->{options} );
    is( $actual, $expected );
}

use Dancer2::Core::Response;
my $resp = Dancer2::Core::Response->new(
    content => '---',
    serializer => Dancer2::Serializer::JSON->new(),
);

$resp->serialize();

done_testing();
