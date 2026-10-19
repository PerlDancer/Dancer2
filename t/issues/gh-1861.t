use strict;
use warnings;

use Test::More tests => 8;
use B ();

use Dancer2::Serializer::JSON;

# GH #1861: the UTF-8 scan in the serializer used to run its regex against the
# values themselves. Matching a regex against a number gives that SV a string
# form alongside its numeric one, and a JSON backend that picks number-vs-string
# from the SV's flags (JSON::XS, and JSON::PP before 2.97) then emits 42 as
# "42". Most installs run Cpanel::JSON::XS, which tolerates such a value, so the
# breakage only showed up elsewhere -- assert on the flags rather than on
# encoded output, so this test fails on any backend.

sub is_pok {
    my ($value) = @_;
    return !!( B::svref_2object( \$value )->FLAGS & B::SVp_POK );
}

ok( !is_pok(42), 'sanity: a fresh integer has no string form' );

my $hash = Dancer2::Serializer::JSON::_ensure_characters( { n => 42 } );
ok( !is_pok( $hash->{n} ), 'integer in a hash keeps no string form' );

my $array = Dancer2::Serializer::JSON::_ensure_characters( [ 42 ] );
ok( !is_pok( $array->[0] ), 'integer in an array keeps no string form' );

my $float = Dancer2::Serializer::JSON::_ensure_characters( { n => 1.5 } );
ok( !is_pok( $float->{n} ), 'float keeps no string form' );

my $nested = Dancer2::Serializer::JSON::_ensure_characters(
    { a => [ { b => 42 } ] } );
ok( !is_pok( $nested->{a}[0]{b} ), 'integer nested in a structure keeps no string form' );

# The caller's own data must not be left stringified either: _ensure_characters
# writes back into arrayrefs in place, so a tainted value would outlive the call.
my $mine = { list => [ 7 ] };
Dancer2::Serializer::JSON::to_json($mine);
ok( !is_pok( $mine->{list}[0] ), 'serializing does not stringify the caller\'s data' );

# ...while the decoding the scan exists for still happens.
is(
    Dancer2::Serializer::JSON::to_json( { n => 42 } ),
    '{"n":42}',
    'integers encode unquoted',
);

is(
    Dancer2::Serializer::JSON::to_json( { t => "D\x{c3}\x{bc}sseldorf" } ),
    "{\"t\":\"D\x{c3}\x{bc}sseldorf\"}",
    'UTF-8 bytes are still decoded and re-encoded',
);
