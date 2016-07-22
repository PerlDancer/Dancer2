use strict;
use warnings;
use utf8;
use Test::More;
use Plack::Test;
use Encode 'encode_utf8';
use HTTP::Request::Common;

subtest 'Query parameters' => sub {
    {
        package App::Basic; ## no critic
        use Dancer2;
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
                'הלו',
                'HMV interface returns encoded values',
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

            ::is(
                $params->get('baz'),
                'הלו',
                'HMV interface returns encoded values',
            );

            ::is(
                params->{'baz'},
                'הלו',
                'Regular interface returns encoded values'
            );
        };
    }

    my $app = Plack::Test->create( App::Body->to_app );
    my $res = $app->request(
        POST '/',
        Content => [foo => 'bar', bar => 'baz', bar => 'quux', baz => 'הלו']
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

            ::is(
                $params->get('baz'),
                'הלו',
                'HMV interface returns encoded values',
            );

            ::is(
                params->{'baz'},
                'הלו',
                'Regular interface returns encoded values'
            );

            return { ok => 1 };
        };
    }

    my $app = Plack::Test->create( App::Body::JSON->to_app );
    my $baz = encode_utf8('הלו');
    my $res = $app->request(
        POST '/', Content => qq{{"foo":"bar","bar":["baz","quux"],"baz":"$baz"}}
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
            ::is( $params->get('value'), 'הלו', 'Got second value' );
            ::is(
                params->{'value'},
                'הלו',
                'Regular interface returns encoded values'
            );
        };
    }

    my $app = Plack::Test->create( App::Route->to_app );

    {
        my $res = $app->request( GET '/bar' );
        ok( $res->is_success, 'Successful request' );
    }

    {
        my $res = $app->request( GET '/foo/הלו' );
        ok( $res->is_success, 'Successful request' );
    }
};

subtest 'Splat and megasplat route parameters' => sub {
    {
        package App::Route::Splat; ## no critic
        use Dancer2;
        get '/*' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );

            ::is_deeply(
                { %{$params} },
                {},
                'All route parameters are empty',
            );

            ::is_deeply(
                [ splat ],
                [ 'foo' ],
                'Got splat values',
            );
        };

        get '/*/*' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword returns Hash::MultiValue object',
            );


            ::is_deeply(
                { %{$params} },
                {},
                'All route parameters are empty',
            );

            ::is_deeply(
                [ splat ],
                [ qw<foo bar> ],
                'Got splat values',
            );
        };

        # /foo/bar/baz/quux/quuks
        get '/*/*/*/**' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword returns Hash::MultiValue object',
            );


            ::is_deeply(
                { %{$params} },
                {},
                'All route parameters are empty',
            );

            ::is_deeply(
                [ splat ],
                [ qw<foo bar baz>, [ qw<quux quuks> ] ],
                'Got splat values',
            );
        };

        # /foo/bar/baz
        get '/*/:foo/**' => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword returns Hash::MultiValue object',
            );

            ::is( $params->get('foo'), 'bar', 'Correct route parameter' );

            ::is_deeply(
                [ splat ],
                [ 'foo', ['baz', ''] ],
                'Got splat values',
            );
        };
    }

    my $app = Plack::Test->create( App::Route::Splat->to_app );

    {
        my $res = $app->request( GET '/foo' );
        ok( $res->is_success, 'Successful request' );
    }

    {
        my $res = $app->request( GET '/foo/bar' );
        ok( $res->is_success, 'Successful request' );
    }

    {
        my $res = $app->request( GET '/foo/bar/baz/quux/quuks' );
        ok( $res->is_success, 'Successful request' );
    }

    {
        my $res = $app->request( GET '/foo/bar/baz/' );
        ok( $res->is_success, 'Successful request' );
    }
};

subtest 'Captured route parameters' => sub {
    {
        package App::Route::Capture; ## no critic
        use Dancer2;
        get qr{^/foo/([^/]+)$} => sub {
            my $params = route_parameters;
            ::isa_ok(
                $params,
                'Hash::MultiValue',
                'parameters keyword',
            );

            ::is_deeply(
                { %{$params} },
                {},
                'All route parameters are empty',
            );

            ::is_deeply(
                [ splat ],
                ['bar'],
                'Correct splat values',
            );

            ::is_deeply(
                captures(),
                +{},
                'capture values are empty',
            );
        };
    }

    my $app = Plack::Test->create( App::Route::Capture->to_app );

    {
        my $res = $app->request( GET '/foo/bar' );
        ok( $res->is_success, 'Successful request' );
    }
};

SKIP: {
    Test::More::skip "named captures not available until 5.10", 1
      if !$^V or $^V lt v5.10;

    subtest 'Named captured route parameters' => sub {
        {
            package App::Route::NamedCapture; ## no critic
            use Dancer2;
            my $re = '^/bar/(?<baz>[^/]+)$';
            get qr{$re} => sub {
                my $params = route_parameters;

                ::isa_ok(
                    $params,
                    'Hash::MultiValue',
                    'parameters keyword',
                );

                ::is_deeply(
                    { %{$params} },
                    {},
                    'All route parameters are empty',
                );

                ::is_deeply(
                    [ splat ],
                    [],
                    'splat values are empty',
                );

                ::is_deeply(
                    captures(),
                    { baz => 'quux' },
                    'Correct capture values',
                );
            };
        }

        my $app = Plack::Test->create( App::Route::NamedCapture->to_app );

        {
            my $res = $app->request( GET '/bar/quux' );
            ok( $res->is_success, 'Successful request' );
        };
    };
};
done_testing();
