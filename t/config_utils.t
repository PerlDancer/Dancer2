use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Dancer2::ConfigUtils qw/normalize_config_entry/;

is( normalize_config_entry( 'charset', 'UTF-8' ), 'utf-8', 'normalized UTF-8 to utf-8');

like(
    exception { normalize_config_entry( 'charset', 'BOGUS' ) },
    qr{Charset defined in configuration is wrong : couldn't identify 'BOGUS'},
    'Configuration file charset failure',
);

done_testing;
