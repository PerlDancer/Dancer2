use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Class::Load 'try_load_class';

try_load_class('CBOR::XS')
    or plan skip_all => 'CBOR::XS is needed for this test';

try_load_class('Dancer2::Serializer::CBOR')
    or plan skip_all => 'Dancer2::Serializer::CBOR is needed for this test';

{
    package App; ## no critic
    use Dancer2;
    set serializer => 'CBOR';
    post '/' => sub {
        ::is_deeply( +{ params() }, +{}, 'Empty parameters' );
        ::is( request->data, 'Foo', 'Correct data using request->data' );
        return 'ok';
    };
}

my $app = Plack::Test->create( App->to_app );
my $res = $app->request(
    POST '/',
    Content => CBOR::XS::encode_cbor('Foo'),
);

ok( $res->is_success, 'Successful response' );
is(
    $res->content,
    CBOR::XS::encode_cbor('ok'),
    'Correct response',
);

done_testing();
