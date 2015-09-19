# this test checks the order of parameters precedence
# we run a few request to a route
# first we check that the route parameters have precedence
# then we check that the body parameters have the next
# and finally, when others aren't available, query parameters
use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package App; ## no critic
    use Dancer2;

    sub query_ok {
        ::is(
            params('query')->{'var'},
            'QueryVar',
            'Query variable exists',
        );
    }

    sub body_ok {
        ::is(
            params('body')->{'var'},
            'BodyVar',
            'Body variable exists',
        );
    }

    sub route_ok {
        ::is(
            params('route')->{'var'},
            'RouteVar',
            'Route variable exists',
        );
    }

    post '/:var' => sub {
        query_ok();
        body_ok();
        route_ok();

        ::is(
            params->{'var'},
            'RouteVar',
            'Route variable wins',
        );

    };

    post '/' => sub {
        query_ok();
        body_ok();

        ::is(
            params->{'var'},
            'BodyVar',
            'Body variable wins',
        );
    };
}

my $test = Plack::Test->create( App->to_app );

subtest 'Route takes precedence over all other parameters' => sub {
    $test->request( POST '/RouteVar?var=QueryVar', [ var => 'BodyVar' ] );
};

subtest 'When route parameters not available, POST takes precedence' => sub {
    $test->request( POST '/?var=QueryVar', [ var => 'BodyVar' ] );
};

done_testing();
