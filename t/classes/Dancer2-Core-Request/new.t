use strict;
use warnings;
use Test::More tests => 9;
use Test::Fatal;
use Plack::Test;
use HTTP::Request::Common;
use Plack::Builder;
use URI::Escape;

BEGIN { use_ok('Dancer2::Core::Request') }

sub psgi_ok { [ 200, [], ['OK'] ] }

sub test_get_params {
    my %exp_params = (
        'name'         => 'Alexis Sukrieh',
        'IRC Nickname' => 'sukria',
        'Project'      => 'Perl Dancer2',
        'hash'         => [ 2, 4 ],
        int1           => 1,
        int2           => 0,
    );

    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );

        is( $request->path,   '/',   'path is set' );
        is( $request->method, 'GET', 'method is set' );
        ok( $request->is_get, 'method is GET' );

        is_deeply(
            scalar( $request->params ),
            \%exp_params,
            'params are OK',
        );

        is(
            $request->params->{'name'},
            'Alexis Sukrieh',
            'params accessor works',
        );

        my %params = $request->params;
        is_deeply(
            scalar( $request->params ),
            \%params,
            'params wantarray works',
        );

        return psgi_ok;
    } );

    my $request_url = '/?' .
        join '&', map {;
            my $param = $_;
            ref $exp_params{$param}
            ? map +( uri_escape($param).'='.uri_escape($_) ), @{ $exp_params{$_} }
            : uri_escape($_).'='.uri_escape( $exp_params{$param} );
        } keys %exp_params;

    ok(
        $test->request( GET $request_url )->is_success,
        'Request successful',
    );
}

sub test_post_params {
    my %exp_params = (
        foo  => 'bar',
        name => 'john',
        hash => [ 2, 4, 6 ],
    );

    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );

        is( $request->path,   '/',    'path is set' );
        is( $request->method, 'POST', 'method is set' );
        ok( $request->is_post, 'method is POST' );

        like(
            $request->to_string,
            qr{^\[\#\d+\] POST /},
            'Request presented well as string',
        );

        is_deeply(
            scalar( $request->params ),
            \%exp_params,
            'params are OK',
        );

        my %params = $request->params;
        is_deeply(
            scalar( $request->params ),
            \%params,
            'params wantarray works',
        );

        is_deeply(
            scalar( $request->params ),
            \%params,
            'params wantarray works',
        );

        return psgi_ok;
    } );

    my $req = POST '/', \%exp_params;

    ok(
        $test->request($req)->is_success,
        'Request successful',
    );
}

sub test_mixed_params {
    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );

        my %exp_params = (
            mixed => {
                x => 1, y => 2, meth => 'post',
            },

            get => {
                y => 2, meth => 'get',
            },

            post => {
                x => 1, meth => 'post',
            },
        );

        is( $request->path,   '/',    'path is set' );
        is( $request->method, 'POST', 'method is set' );

        is_deeply(
            scalar( $request->params ),
            $exp_params{'mixed'},
            'params are OK',
        );

        is_deeply(
            scalar( $request->params('body') ),
            $exp_params{'post'},
            'body params are OK',
        );

        is_deeply(
            scalar( $request->params('query') ),
            $exp_params{'get'},
            'query params are OK',
        );

        return psgi_ok;
    } );

    my $req = POST '/?y=2&meth=get',
        { x => 1, meth => 'post' };

    ok(
        $test->request($req)->is_success,
        'Request successful',
    );
}

sub test_all_params {
    test_get_params;
    test_post_params;
    test_mixed_params;
}

subtest 'Defaults' => sub {
    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );
        isa_ok( $request, 'Dancer2::Core::Request' );

        can_ok( $request, 'env' );
        isa_ok( $request->env, 'HASH' );

        # http env keys
        my @http_env_keys = qw<
            accept accept_charset accept_encoding accept_language
            connection keep_alive referer user_agent x_requested_with
        >;

        can_ok( $request, @http_env_keys );

        is(
            $request->$_,
            $request->env->{"HTTP_$_"},
            "HTTP ENV key $_",
        ) for @http_env_keys;

        is(
            $request->agent,
            $request->user_agent,
            'agent as alias to user_agent',
        );

        is(
            $request->remote_address,
            $request->address,
            'remote_address as alias to address',
        );

        # variables
        $request->var( foo => 'bar' );
        is_deeply(
            $request->vars,
            { foo => 'bar' },
            'Setting variables using DSL',
        );

        is( $request->var('foo'), 'bar', 'Read single variable' );

        $request->var( foo => 'baz' );

        is_deeply(
            $request->vars,
            { foo => 'baz' },
            'Overwriting variables using vars() method',
        );

        is( $request->var('foo'), 'baz', 'Read variable' );

        is( $request->path,      '/defaults', 'Default path'      );
        is( $request->path_info, '/defaults', 'Default path_info' );
        is( $request->method,    'GET',       'Default method'    );

        is( $request->id, 1, 'Correct request ID' );

        my %aliases = (
            address     => 'REMOTE_ADDR',
            remote_host => 'REMOTE_HOST',
            protocol    => 'SERVER_PROTOCOL',
            port        => 'SERVER_PORT',
            request_uri => 'REQUEST_URI',
            user        => 'REMOTE_USER',
            script_name => 'SCRIPT_NAME',
        );

        is(
            $request->$_,
            $request->env->{ $aliases{$_} },
            "$_ derived from $aliases{$_}",
        ) for keys %aliases;

        is(
            $request->to_string,
            '[#1] GET /defaults',
            'Correct to_string',
        );

        return psgi_ok;
    } );

    ok(
        $test->request( GET '/defaults' )->is_success,
        'Request successful',
    );
};

subtest 'Create with single env' => sub {
    isa_ok(
        Dancer2::Core::Request->new( env => {} ),
        'Dancer2::Core::Request',
        'Create with env hash',
    );

    my $request;
    isa_ok(
        $request = Dancer2::Core::Request->new(
            env => { REQUEST_METHOD => 'X' }
        ),
        'Dancer2::Core::Request',
        'Create with single argument for env',
    );

    is( $request->method, 'X', 'env() attribute populated successfully' );
};

subtest 'Serializer' => sub {
    {
        my $request = Dancer2::Core::Request->new( env => {} );
        can_ok( $request, qw<serializer> );
        ok( ! $request->serializer, 'No serializer set' );
    }

    {
        { package Nothing; use Moo; }

        # The type check fails - BUILD is not called, no increment of _count.
        ok(
            exception {
                Dancer2::Core::Request->new(
                    env        => {},
                    serializer => Nothing->new,
                )
            },
            'Cannot send random object to request as serializer',
        );

        {
            package Serializer;
            use Moo;
            with 'Dancer2::Core::Role::Serializer';
            sub serialize {1}
            sub deserialize {1}
            has '+content_type' => ( default => sub {1} );
        }

        my $request;
        is(
            exception {
                $request = Dancer2::Core::Request->new(
                    env        => { REQUEST_METHOD => 'GET' },
                    serializer => Serializer->new,
                )
            },
            undef,
            'Can create request with serializer',
        );

        ok( $request->serializer, 'Serializer set' );
        isa_ok( $request->serializer, 'Serializer' );
    }
};

subtest 'Path when mounting' => sub {
    my $app  = builder { mount '/mount' => sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );

        is(
            $request->script_name,
            '/mount',
            'Script name when mounted (script_name)',
        );

        is(
            $request->request_uri,
            '/mount/mounted_path',
            'Correct request_uri',
        );

        is(
            $request->path,
            '/mounted_path',
            'Full path when mounted (path)',
        );

        is(
            $request->path_info,
            '/mounted_path',
            'Mounted path when mounted (path_info)',
        );

        return psgi_ok;
    } };

    my $test = Plack::Test->create($app);

    ok(
        $test->request( GET '/mount/mounted_path' )->is_success,
        'Request successful',    
    );
};

subtest 'Different method' => sub {
    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );

        is( $request->method, 'PUT', 'Correct method' );

        is(
            $request->env->{'REQUEST_METHOD'},
            $request->method,
            'REQUEST_METHOD derived from env',
        );

        return psgi_ok;
    } );

    ok(
        $test->request( PUT '/' )->is_success,
        'Request successful',
    );
};

# the calling order to this method matters because it checks
# how many requests were run so far
subtest 'Checking request ID' => sub {
    my $test = Plack::Test->create( sub {
        my $env     = shift;
        my $request = Dancer2::Core::Request->new( env => $env );
        is( $request->id, 8, 'Correct request id' );

        return psgi_ok;
    } );

    ok(
        $test->request( GET '/' )->is_success,
        'Request successful',
    );
};

subtest 'is_$method (head/post/get/put/delete/patch' => sub {
    foreach my $http_method ( qw<head post get put delete patch> ) {
        my $test = Plack::Test->create( sub {
            my $env     = shift;
            my $request = Dancer2::Core::Request->new( env => $env );
            my $method  = "is_$http_method";
            ok( $request->$method, $method );
            return psgi_ok;
        } );

        ok(
            $test->request(
                HTTP::Request->new( ( uc $http_method ) => '/' )
            )->is_success,
            'Request successful',
        );
    }
};

subtest 'Parameters (body/query/route)' => sub {
    note $Dancer2::Core::Request::XS_URL_DECODE ?
         'Running test with XS_URL_DECODE'      :
         'Running test without XS_URL_DECODE';

    note $Dancer2::Core::Request::XS_PARSE_QUERY_STRING ?
         'Running test with XS_PARSE_QUERY_STRING'      :
         'Running test without XS_PARSE_QUERY_STRING';

    test_all_params;

    if ( $Dancer2::Core::Request::XS_PARSE_QUERY_STRING ) {
        note 'Running test without XS_PARSE_QUERY_STRING';
        $Dancer2::Core::Request::XS_PARSE_QUERY_STRING = 0;
        test_all_params;
    }

    if ( $Dancer2::Core::Request::XS_URL_DECODE ) {
        note 'Running test without XS_URL_DECODE';
        $Dancer2::Core::Request::XS_URL_DECODE = 0;
        test_all_params;
    }
};

# more stuff to test

# special methods:
# forwarded_for_address
# forwarded_protocol
# forwarded_host
# host

#subtest 'Behind proxy (host/is_behind_proxy)' => sub {
#    my $test = Plack::Test->create( sub { psgi_ok } );
#
#    ok(
#        $test->request( GET '/dev/null' )->is_success,
#        'Different method request successful',
#    );
#};

#subtest 'Path resolution methods' => sub {
#    my $test = Plack::Test->create( sub {
#        my $env     = shift;
#        my $request = Dancer2::Core::Request->new( env => $env );
#
#        return psgi_ok;
#    } );
#};

#subtest 'Upload' => sub {1};
#subtest 'Scheme' => sub {1};
#subtest 'Cookies' => sub {1};
#subtest 'Headers' => sub {1};
