use strict;
use warnings;

use Test::More tests => 7;

use Dancer2::Serializer::JSON;

# GH #1863: serializing must not disturb the entity it is given. It belongs to
# the application, which may hold on to it and serialize it again -- so a
# decoded key or value has to go into a new container, not be written back.

# A hash key that needs decoding used to be deleted from the caller's hash and
# added only to the copy being encoded, so the entry vanished from the app's
# data after the first serialize.
{
    my $cache = { "caf\xc3\xa9" => 'open', bar => 'shut' };

    my $first = Dancer2::Serializer::JSON::to_json( $cache, { canonical => 1 } );
    my $second = Dancer2::Serializer::JSON::to_json( $cache, { canonical => 1 } );

    is( $second, $first, 'serializing twice gives the same JSON' );
    is_deeply(
        [ sort keys %$cache ],
        [ sort "caf\xc3\xa9", 'bar' ],
        'the non-ASCII key survives serialization',
    );
    is( $cache->{"caf\xc3\xa9"}, 'open', 'and still has its value' );
}

# Arrayrefs were decoded in place, converting the app's bytes to characters.
{
    my $data = { tags => [ "caf\xc3\xa9", 'plain' ] };

    Dancer2::Serializer::JSON::to_json($data);

    is( $data->{tags}[0], "caf\xc3\xa9", 'array element left as the caller had it' );
    ok( !utf8::is_utf8( $data->{tags}[0] ), 'and not decoded in place' );
}

# Nested containers must be left alone too, not just the top level.
{
    my $data = { outer => [ { "caf\xc3\xa9" => [ "na\xc3\xafve" ] } ] };

    Dancer2::Serializer::JSON::to_json($data);

    is_deeply(
        $data,
        { outer => [ { "caf\xc3\xa9" => [ "na\xc3\xafve" ] } ] },
        'nested structure is untouched',
    );
}

# ...while the output itself still has everything decoded properly.
is(
    Dancer2::Serializer::JSON::to_json(
        { "caf\xc3\xa9" => [ "na\xc3\xafve" ] }, { canonical => 1 }
    ),
    "{\"caf\xc3\xa9\":[\"na\xc3\xafve\"]}",
    'keys and values are still decoded and re-encoded in the output',
);
