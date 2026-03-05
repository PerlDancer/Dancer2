use strict;
use warnings;
use Test::More 'tests' => 3;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use JSON::MaybeXS;

{
    package App;
    use Dancer2;
    our $tested;

    # Static with route params
    # Static with code
    # Static with options and code
    get 'view_entry_static1' => '/view1/:id' => sub {1};
    get 'view_entry_static2' => '/view2/:id' => { 'user_agent' => 'UA/1.0' }, sub {1};

    # static with typed route param
    get 'view_user' => '/:prefix/user/:username[Str]' => sub {1};

    # splat / megasplat
    get 'view_entry_splat' => '/viewsplat/*/*/**' => sub {1};

    # Mixed with splat/megasplat
    # Different method
    patch 'view_entry_mixed' => '/view_mixed/*/**/:id' => sub {1};

    # Regexp - fails
    get 'view_entry_regexp1' => qr{/rview1/[0-9]+} => sub {1};

    post '/uri_for_route' => sub {
        my $params = JSON::MaybeXS::decode_json( request->content );
        return uri_for_route(
            $params->{'route_name'},
            $params->{'route_params'},
            $params->{'query_params'} // {},
            !!$params->{'dont_escape'},
        );
    };

    get '/fail_uri_for_route' => sub {
        my $failed = 0;
        eval {
            uri_for_route('vvv');
            1;
        } or do {
            ::like(
                $@,
                qr/\QCannot find route named 'vvv'\E/xms,
                'Cannot retrieve nonexistent route',
            );

            $failed++;
        };

        return $failed;
    };

    get '/fail_uri_for_route_splat_args' => sub {
        my $failed = 0;
        eval {
            uri_for_route(
                'view_entry_splat',
                ['foo'],
            );

            1;
        } or do {
            ::like(
                $@,
                qr/\QMismatch in amount of splat args and splat elements\E/xms,
                'Cannot handle mismatched splat args and elements',
            );

            $failed++;
        };

        return $failed;
    };

    get '/fail_uri_for_route_leftovers' => sub {
        my $failed = 0;
        eval {
            uri_for_route('view_entry_static1');
            1;
        } or do {
            my $msg = 'Route view_entry_static1 uses the parameter \'id\', '
                    . 'which was not provided';

            ::like(
                $@,
                qr/\Q$msg\E/xms,
                'Cannot handle leftover route parameters',
            );

            $failed++;
        };

        return $failed;
    };

    # Error defining two routes with the same name, regardless of method
    eval {
        get 'view_entry_splat' => '/' => sub {1};
        1;
    } or do {
        ::like(
            $@,
            qr/\QRoute with this name (view_entry_splat) already exists\E/xms,
            'Cannot register two routes with same name',
        );

        $tested = 1;
    };
}

sub test_app {
    my ( $app, $mount_path ) = @_;

    my $prefix = 'http://localhost';
    $mount_path
        and $prefix .= $mount_path;

    my ( $path, $res );

    # Test static paths
    foreach my $idx ( 1 .. 2 ) {
        $res = $app->request(
            POST(
                "$prefix/uri_for_route",
                'Content' => JSON::MaybeXS::encode_json({
                    'route_name'   => "view_entry_static$idx",
                    'route_params' => { 'id'  => $idx },
                    'query_params' => { 'foo' => $idx },
                }),
            )
        );

        $path = "$prefix/view$idx/$idx?foo=$idx";
        ok( $res->is_success, 'Successful request' );
        is( $res->content, $path, "Correct path: $path" );
    }

    # Test splat + megasplat
    $res = $app->request(
        POST(
            "$prefix/uri_for_route",
            'Content' => JSON::MaybeXS::encode_json({
                'route_name'   => 'view_entry_splat',
                'route_params' => [ 'foo', 'bar', [ 'baz', 'quux' ] ],
                'query_params' => { 'id' => 'di' },
            }),
        )
    );

    $path = "$prefix/viewsplat/foo/bar/baz/quux?id=di";
    ok( $res->is_success, 'Successful request' );
    is( $res->content, $path, "Correct path: $path" );

    # Test mixed
    $res = $app->request(
        POST(
            "$prefix/uri_for_route",
            'Content' => JSON::MaybeXS::encode_json(
                {   'route_name'   => 'view_entry_mixed',
                    'route_params' => {
                        'id'    => 'di',
                        'splat' => ['foo', ['bar', 'baz']]
                    },
                    'query_params' => {'foo' => 'bar'},
                }
            ),
        )
    );

    $path = "$prefix/view_mixed/foo/bar/baz/di?foo=bar";
    ok( $res->is_success, 'Successful request' );
    is( $res->content, $path, "Correct path: $path" );

    # Test escaping
    $res = $app->request(
        POST(
            "$prefix/uri_for_route",
            'Content' => JSON::MaybeXS::encode_json({
                'route_name'   => 'view_entry_static1',
                'route_params' => { 'id' => '!@£$%' },
            }),
        )
    );

    $path = "$prefix/view1/!@%C3%82%C2%A3\$%";
    ok( $res->is_success, 'Successful request' );
    is( $res->content, $path, "Correct path: $path" );

    # Test nonexistent route name
    $res = $app->request( GET "$prefix/fail_uri_for_route" );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '1', 'Successfully tested nonexistent failure mode' );

    # Test splat + megasplat (incorrect amount)
    $res = $app->request( GET "$prefix/fail_uri_for_route_splat_args" );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '1', 'Successfully tested mismatch splat args/elements failure mode' );

    # Test mixed with not all filled (named args left)
    $res = $app->request( GET "$prefix/fail_uri_for_route_leftovers" );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '1', 'Successfully tested leftover args failure mode' );

    # Static with typed route parameters
    $res = $app->request(
        POST(
            "$prefix/uri_for_route",
            'Content' => JSON::MaybeXS::encode_json({
                'route_name' => 'view_user',
                'route_params' => { 'prefix' => 'foo', 'username' => 'sawyer' },
                'query_params' => { 'foo' => 1 },
            }),
        )
    );

    $path = "$prefix/foo/user/sawyer?foo=1";
    ok( $res->is_success, 'Successful request' );
    is( $res->content, $path, "Correct path for typed route param: $path" );
}

subtest 'Non-mounted app' => sub {
    my $app = Plack::Test->create( App->to_app );
    test_app($app);
    ok( $App::tested, 'Check for duplicate route names done successfully' );
};

subtest 'Mounted app' => sub {
    my $app = Plack::Test->create(
        builder {
            mount '/mount' => App->to_app;
            mount '/'      => sub {
                return { Plack::Response->new(200, [], ['OK'] ) }
            },
        }
    );

    test_app( $app, '/mount' );
};
