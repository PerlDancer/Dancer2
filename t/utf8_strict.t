use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Encode qw(encode);

use Dancer2::Core::Request;
use Dancer2::Serializer::JSON;

subtest 'request path decoding (lenient)' => sub {
    my $bytes = encode( 'UTF-8', "/\x{00F8}" );
    my $req = Dancer2::Core::Request->new(
        env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => $bytes,
        },
    );

    my $path = $req->path;
    is( ord( substr( $path, 1, 1 ) ), 0xF8, 'decoded UTF-8 path' );
    ok( utf8::is_utf8($path), 'decoded path is characters' );
};

subtest 'request path decoding (invalid utf8, lenient)' => sub {
    my $bad = '/' . pack( 'C', 0xFF );
    my $req = Dancer2::Core::Request->new(
        env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => $bad,
        },
    );

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $path = $req->path;

    is( $path, $bad, 'invalid UTF-8 left as bytes' );
    like( $warnings[0], qr/Invalid UTF-8/, 'warned on invalid UTF-8' );
};

subtest 'request path decoding (invalid utf8, strict)' => sub {
    my $req = Dancer2::Core::Request->new(
        env => {
            REQUEST_METHOD => 'GET',
            PATH_INFO      => '/' . pack( 'C', 0xFF ),
        },
        strict_utf8 => 1,
    );

    my $error = exception { $req->path };
    like( $error, qr/Invalid UTF-8/, 'strict mode rejects invalid UTF-8' );
};

subtest 'json serialization (lenient + strict)' => sub {
    my $bad = pack( 'C', 0xFF );

    my @warnings;
    my $serializer = Dancer2::Serializer::JSON->new(
        config => { strict_utf8 => 0 },
        log_cb => sub { push @warnings, $_[1] },
    );
    my $json = $serializer->serialize( { bad => $bad } );
    ok( $json, 'serialize succeeded in lenient mode' );
    like( $warnings[0], qr/Invalid UTF-8/, 'warned on invalid UTF-8' );

    my $strict_bad = pack( 'C', 0xFF );
    my $strict = Dancer2::Serializer::JSON->new(
        config => { strict_utf8 => 1 },
        log_cb => sub {1},
    );
    my $error = exception { $strict->serialize( { bad => $strict_bad } ) };
    like( $error, qr/Invalid UTF-8/, 'strict mode rejects invalid UTF-8' );
};

done_testing();
