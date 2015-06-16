use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Class::Load 'try_load_class';

{
    package App::CBOR; ## no critic
    use Dancer2;
    set serializer => 'CBOR';
    post '/' => sub {
        ::is_deeply( +{ params() }, +{}, 'Empty parameters' );
        ::is( request->data, 'Foo', 'Correct data using request->data' );
        return 'ok';
    };
}

subtest 'Testing with CBOR' => sub {
    try_load_class('CBOR::XS')
        or plan skip_all => 'CBOR::XS is needed for this test';

    try_load_class('Dancer2::Serializer::CBOR')
        or plan skip_all => 'Dancer2::Serializer::CBOR is needed for this test';

    my $app = Plack::Test->create( App::CBOR->to_app );
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
};

{
    package App::JSON; ## no critic
    use Dancer2;
    set serializer => 'JSON';
    post '/' => sub {
        ::is_deeply( +{ params() }, +{}, 'Empty parameters' );
        ::is_deeply(
            request->data,
            [ qw<foo bar> ],
            'Correct data using request->data',
        );
        return [ qw<foo bar> ];
    };
}

subtest 'Testing with JSON' => sub {
    my $app = Plack::Test->create( App::JSON->to_app );
    my $res = $app->request(
        POST '/',
        Content => '["foo","bar"]',
    );

    ok( $res->is_success, 'Successful response' );
    is(
        $res->content,
        '["foo","bar"]',
        'Correct response',
    );
};

done_testing();
