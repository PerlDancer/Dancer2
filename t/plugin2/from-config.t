use strict;
use warnings;

use Test::More tests => 5;

{
package Dancer2::Plugin::FromConfig;

use Dancer2::Plugin;

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

has five => (
    is => 'ro',
    from_config => sub { 'cinq' },
);

has six => (
    is => 'ro',
    from_config => sub { 'six' },
    default => sub { 'AH!' },
    plugin_keyword => 1,
);

plugin_keywords qw/ one three four five /;

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
    Test::More::is five() => 'cinq', 'from_config a coderef';
    Test::More::is six() => 'AH!', 'from_config a coderef, no override';
}



