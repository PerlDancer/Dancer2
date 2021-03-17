use strict;
use warnings;
use Test::More;

# TODO: Remove this test when GH #1319 is done.
# This test is intended to be temporary until then.
eval { require App::Cmd::Setup; 1; }
    or plan skip_all => 'App::Cmd::Setup required for this test';

plan tests => 3;
use_ok 'Dancer2::CLI';
use_ok 'Dancer2::CLI::Command::gen';
use_ok 'Dancer2::CLI::Command::version';
