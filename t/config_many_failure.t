use strict;
use warnings;

use Test::More;
use File::Spec;
use English;

BEGIN {
    # undefine ENV vars used as defaults for app environment in these tests
    local $ENV{DANCER_ENVIRONMENT};
    local $ENV{PLACK_ENV};
    $ENV{DANCER_CONFIG_READERS}
        = 'Dancer2::ConfigReader::Config::Any Dancer2::ConfigReader::TestDummy';
}

use lib q{.};
use lib './t/lib';

local $EVAL_ERROR = undef;
my $eval_r = eval 'use t::app::t1::lib::App1;';
my $eval_e = $EVAL_ERROR;
is $eval_r, undef, 'Eval failed correctly';
like $eval_e, qr{`Dancer2::ConfigReader::Config::Any Dancer2::ConfigReader::TestDummy' is not a module name}, 'Correct dying and error';

done_testing;
