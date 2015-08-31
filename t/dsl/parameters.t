use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

subtest 'Query parameters' => sub {
    {
        package App::Basic; ## no critic
        use Dancer2;
        use Encode 'encode_utf8';
        get '/' => sub {
            my $params = query_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );

            ::is( $params->get('foo'), 'bar', 'Got single value' );
            ::is(
                $params->get('bar'),
                'quux',
                'Got single value from multi key',
            );

            ::is_deeply(
                [ $params->get_all('bar') ],
                ['baz', 'quux'],
                'Got multi value from multi key',
            );

            ::is(
                $params->get('baz'),
                encode_utf8('הלו'),
                'HMV interface returns decoded values',
            );

            ::is(
                params->{'baz'},
                'הלו',
                'Regular interface returns encoded values'
            );
        };
    }

    my $app = Plack::Test->create( App::Basic->to_app );
    my $res = $app->request( GET '/?foo=bar&bar=baz&bar=quux&baz=הלו' );
    ok( $res->is_success, 'Successful request' );
};

subtest 'Body parameters' => sub {
    {
        package App::Body; ## no critic
        use Dancer2;
        post '/' => sub {
            my $params = body_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );
 
            ::is( $params->get('foo'), 'bar', 'Got single value' );
            ::is(
                $params->get('bar'),
                'quux',
                'Got single value from multi key',
            );

            my $z = [ $params->get_all('bar') ];
            ::is_deeply(
                [ $params->get_all('bar') ],
                ['baz', 'quux'],
                'Got multi value from multi key',
            );
        };
    }

    my $app = Plack::Test->create( App::Body->to_app );
    my $res = $app->request(
        POST '/', Content => [ foo => 'bar', bar => 'baz', bar => 'quux' ]
    );
    ok( $res->is_success, 'Successful request' );
};

subtest 'Body parameters with serialized data' => sub {
    {
        package App::Body::JSON; ## no critic
        use Dancer2;
        set serializer => 'JSON';
        post '/' => sub {
            my $params = body_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );

            ::is( $params->get('foo'), 'bar', 'Got single value' );
            ::is(
                $params->get('bar'),
                'quux',
                'Got single value from multi key',
            );

            my $z = [ $params->get_all('bar') ];
            ::is_deeply(
                [ $params->get_all('bar') ],
                ['baz', 'quux'],
                'Got multi value from multi key',
            );

            return { ok => 1 };
        };
    }

    my $app = Plack::Test->create( App::Body::JSON->to_app );
    my $res = $app->request(
        POST '/', Content => '{"foo":"bar","bar":["baz","quux"]}'
    );
    ok( $res->is_success, 'Successful request' );
};

subtest 'Route parameters' => sub {
    {
        package App::Route; ## no critic
        use Dancer2;
        get '/:foo' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );

            ::is( $params->get('foo'), 'bar', 'Got keyed value' );
        };

        get '/:name/:value' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword returns Hash::MultiValue object',
            );

            ::is( $params->get('name'), 'foo', 'Got first value' );
            ::is( $params->get('value'), 'bar', 'Got second value' );
        };
    }

    my $app = Plack::Test->create( App::Route->to_app );

    {
        my $res = $app->request( GET '/bar' );
        ok( $res->is_success, 'Successful request' );
    }

    {
        my $res = $app->request( GET '/foo/bar' );
        ok( $res->is_success, 'Successful request' );
    }
};

done_testing();
