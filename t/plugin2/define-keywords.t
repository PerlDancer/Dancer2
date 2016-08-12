use strict;
use warnings;

use lib 't/lib';

use Test::More;

plan skip_all => 'Perl >=5.12 required' if $] < 5.012;

plan tests => 2;

use Dancer2;
use Dancer2::Plugin::DefineKeywords;

my $plugin = Dancer2::Plugin::DefineKeywords->new( app => undef );

subtest "keywords are registered" => sub {
    for my $keyword ( @::expected_keywords ) {
        ok( ( scalar grep { $_ eq $keyword  } keys %{ $plugin->keywords } ), $keyword );
    }
};

subtest "keywords are recognized" => sub {
    is foo() => 'foo', 'foo';
    is bar() => 'bar', 'bar';
    is quux() => 'quux', 'quux';
};

