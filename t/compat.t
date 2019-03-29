use strict;
use warnings;
use utf8;

use Test::More tests => 5;

no warnings 'redefine','once';

BEGIN {
    # Force use of wrapper versions by explicitly breaking import methods
    require MIME::Base64;
    require List::Util;

    local *MIME::Base64::import = sub { die };
    local *List::Util::import = sub { die };

    require Dancer2::Compat;
    Dancer2::Compat->import(qw/encode_base64url pairgrep pairmap/);
}

my $encoded = encode_base64url('https://foo.bar.com?p=1&q=2');
is($encoded, 'aHR0cHM6Ly9mb28uYmFyLmNvbT9wPTEmcT0y', 'encode_base64url wrapper');

my $pairmap = [ pairmap { $a + $b } (1,2,3,4) ];
is_deeply($pairmap, [ 3, 7 ], 'pairmap wrapper');

my $pairmap_s = scalar pairmap { $a + $b } (1,2,3,4);
is($pairmap_s, 2, 'pairmap wrapper (scalar)');

my $pairgrep = [ pairgrep { $a & 0x1 } (1,2,4,3,2,2,3,3) ];
is_deeply($pairgrep, [ 1, 2, 3, 3 ], 'pairgrep wrapper');

my $pairgrep_s = scalar pairgrep { $a & 0x1 } (1,2,4,3,2,2,3,3);
is($pairgrep_s, 2, 'pairgrep wrapper (scalar)');
