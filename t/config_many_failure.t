use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Spec;
use English;

use Dancer2::Core::App;

BEGIN {
    # undefine ENV vars used as defaults for app environment in these tests
    local $ENV{DANCER_ENVIRONMENT};
    local $ENV{PLACK_ENV};
}

use lib q{.};
use lib './t/lib';

subtest 'bad DANCER_CONFIG_READERS' => sub {
    # space instead of comma, ooops
    $ENV{DANCER_CONFIG_READERS}
        = 'Dancer2::ConfigReader::Config::Any Dancer2::ConfigReader::TestDummy';

    throws_ok {
        Dancer2::Core::App->new( name => 'basic' );
    } qr{`Dancer2::ConfigReader::Config::Any Dancer2::ConfigReader::TestDummy' is not a module name};
};

subtest 'infinite loop of configs' => sub {
    $ENV{DANCER_CONFIG_READERS}
        = 'Dancer2::ConfigReader::Recursive';

    throws_ok {
        Dancer2::Core::App->new( name => 'basic' );
    } qr{MAX_CONFIGS exceeded};
};

done_testing;
