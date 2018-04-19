use strict;
use warnings;

use Test::More tests => 8;

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

has [qw(seven eight)] => (
    is => 'ro',
    from_config => 1,
    plugin_keyword => 1,
);

eval {
    has [qw(nine ten)] => (
        is => 'ro',
        from_config => 1,
        plugin_keyword => ['nine', 'ten'],
    );
};
our $plugin_keyword_exception = $@;

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
            },
            seven => 'sept',
            eight => 'huit',
        }
    };


    Test::More::is one() => 'un', 'from config';
    Test::More::is three() => 'trois', 'from config, nested';
    Test::More::is four() => 'quatre', 'nothing in config, default value';
    Test::More::is five() => 'cinq', 'from_config a coderef';
    Test::More::is six() => 'AH!', 'from_config a coderef, no override';
    Test::More::is seven() => 'sept', 'from_config, defined two fields at once #1';
    Test::More::is eight() => 'huit', 'from_config, defined two fields at once #2';
    Test::More::ok $Dancer2::Plugin::FromConfig::plugin_keyword_exception,
        "defining two fields simultaneously with multiple plugin_keyword values"
        . " is disallowed";
}



