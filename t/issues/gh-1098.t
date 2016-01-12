use Test::More tests => 5;
use Test::Fatal;

use Dancer2::Core::Error;
use Dancer2::Core::Response;
use Dancer2::Serializer::JSON;
use JSON;

is exception { Dancer2::Core::Error->new }, undef, "Error->new lived";

like exception { Dancer2::Core::Error->new(show_errors => []) },
  qr/not.+boolean/i, "Error->new(show_errors => []) died";

is exception {
    Dancer2::Core::Error->new(serializer => undef)
}, undef, "Error->new(serializer => undef) lived";

is exception {
    Dancer2::Core::Error->new(serializer => Dancer2::Serializer::JSON->new)
}, undef, "Error->new(serializer => Dancer2::Serializer::JSON->new) lived";

like exception { Dancer2::Core::Error->new(serializer => JSON->new) },
  qr/does not have role/, "Error->new(serializer => JSON->new) died";
