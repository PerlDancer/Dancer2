use Test::More tests => 3;
use Test::Fatal;

use Dancer2::Core::Error;
use Dancer2::Core::Response;
use Dancer2::Serializer::JSON;
use HTTP::Headers;
use HTTP::Headers::Fast;
use JSON::MaybeXS;

subtest 'Core::Error serializer isa tests' => sub {
    plan tests => 5;

    is exception { Dancer2::Core::Error->new }, undef, "Error->new lived";

    like exception { Dancer2::Core::Error->new(show_errors => []) },
    qr/Reference \Q[]\E did not pass type constraint "Bool"/i,
      "Error->new(show_errors => []) died";

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

    like exception { Dancer2::Core::Error->new(serializer => JSON->new) }, qr/
    (
    requires\sthat\sthe\sreference\sdoes\sDancer2::Core::Role::Serializer
    |
    did\snot\spass\stype\sconstraint
    )
    /x, "Error->new(serializer => JSON->new) died";
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

subtest 'Core::Role::Logger log_level isa tests' => sub {
    plan tests => 1 + 6 + 1;

    {
        package TestLogger;
        use Moo;
        with 'Dancer2::Core::Role::Logger';
        sub log { }
    }

    is exception { TestLogger->new }, undef, "Logger->new lived";

    my @levels = qw/core debug info warn warning error/;
    foreach my $level (@levels) {
        is exception { TestLogger->new(log_level => $level) }, undef,
          "Logger->new(log_level => $level) lives";
    }

    like exception { TestLogger->new(log_level => 'BadLevel') },
    qr/Value "BadLevel" did not pass type constraint "Enum/,
      "Logger->new(log_level => 'BadLevel') died";
};
