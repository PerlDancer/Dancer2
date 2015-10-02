use strict;
use warnings;

use Test::More tests => 3;

{
package Dancer2::Plugin::FromConfig;

use Dancer2::Plugin2;

BEGIN {
has one => (
    is => 'ro',
    from_config => 1,
);

has three => (
    is => 'ro',
    from_config => 'two.three',
);

has four => (
    is => 'ro',
    from_config => 1,
    default => sub { 'quatre' },
);

plugin_keywords qw/ one three four /;

}
}

{
    package MyApp;

    use Dancer2;

    use Dancer2::Plugin::FromConfig;

    set plugins => {
        FromConfig => {
            one => 'un',
            two => {
                three => 'trois',
            }
        }
    };


    Test::More::is one() => 'un', 'from config';
    Test::More::is three() => 'trois', 'from config, nested';
    Test::More::is four() => 'quatre', 'nothing in config, default value';
}



