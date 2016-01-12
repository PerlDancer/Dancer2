use Test::More tests => 2;
use Test::Fatal;

use Dancer2::Core::Error;
use Dancer2::Core::Response;
use Dancer2::Serializer::JSON;
use HTTP::Headers::Fast;
use JSON;

subtest 'Core::Error serializer isa tests' => sub {
    plan tests => 5;

    is exception { Dancer2::Core::Error->new }, undef, "Error->new lived";

    like exception { Dancer2::Core::Error->new(show_errors => []) },
    qr/not.+boolean/i, "Error->new(show_errors => []) died";

    is exception {
        Dancer2::Core::Error->new(serializer => undef)
    },
    undef,
    "Error->new(serializer => undef) lived";

    is exception {
        Dancer2::Core::Error->new(serializer => Dancer2::Serializer::JSON->new)
    },
    undef,
    "Error->new(serializer => Dancer2::Serializer::JSON->new) lived";

    like exception { Dancer2::Core::Error->new(serializer => JSON->new) },
    qr/does not have role/,
    "Error->new(serializer => JSON->new) died";
};

subtest 'Core::Response headers isa tests' => sub {
    plan tests => 5;

    is exception { Dancer2::Core::Response->new },
    undef, "Response->new lived";

    is exception {
        Dancer2::Core::Response->new(headers => [Header => 'Content'])
    },
    undef,
    "Response->new( headers => [ Header => 'Content' ] ) lived";

    is exception {
        Dancer2::Core::Response->new(headers => HTTP::Headers->new)
    },
    undef,
    "Response->new( headers => HTTP::Headers->new ) lived";

    is exception {
        Dancer2::Core::Response->new(headers => HTTP::Headers::Fast->new)
    },
    undef,
    "Response->new( headers => HTTP::Headers::Fast->new ) lived";

    like exception {
        Dancer2::Core::Response->new(headers => JSON->new)
    },
    qr/coercion.+failed.+not.+array/i,
    "Response->new( headers => JSON->new ) died";
};

