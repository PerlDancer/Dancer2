use strict;
use warnings;

use Test::More;
use File::Spec;

use lib '.';
use t::app::t3::lib::App4;

my ($app) = @{ Dancer2->runner->apps };
my $trap = $app->logger_engine->trapper;
my $logs = $trap->read;

like( $logs->[0]{message}, qr/Built config from files/, 'log message ok');

done_testing;

