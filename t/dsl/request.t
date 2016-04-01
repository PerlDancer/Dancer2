use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::DSL::Request;
    use Dancer2;

    any [ 'get', 'post' ], '/' => sub {
        request->method;
    };

    get 'headers' => sub {
        request_header 'X-Foo';
    };
}

subtest 'Testing an app with request keyword' => sub {
    my $test = Plack::Test->create( App::DSL::Request->to_app );
    {
        my $res = $test->request( GET '/' );
        ok( $res->is_success, 'Successful GET request' );
        is( $res->content, 'GET', 'GET / correct content' );    
    }
    {
        my $res = $test->request( POST '/' );
        ok( $res->is_success, 'Successful POST request' );
        is( $res->content, 'POST', 'POST / correct content' );    
    }
};

subtest 'Testing app with request_header heyword' => sub {
    my $test = Plack::Test->create( App::DSL::Request->to_app );
    my $res = $test->request( GET '/headers', 'X-Foo' => 'Bar' );
    ok( $res->is_success, 'Successful GET request' );
    is( $res->content, 'Bar', 'GET /headers correct content' );    
};

done_testing;

