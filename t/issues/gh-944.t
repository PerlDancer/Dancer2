use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package RouteContentTest; ## no critic
    use Dancer2;
    set serializer => 'JSON';

    hook before => sub {
        return if request->dispatch_path eq '/content';
        response->content({ foo => 'bar' });
        response->halt;
    };

    get '/' => sub {1};

    get '/content' => sub {
        response->content({ foo => 'bar' });
        return 'this is ignored';
    };
}

my $test = Plack::Test->create( RouteContentTest->to_app );

subtest "response set in before hook" => sub {
    my $res = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '{"foo":"bar"}', 'Correct content' );
};

subtest "response content set in route" => sub {
    my $res = $test->request( GET '/content' );
    ok( $res->is_success, 'Successful request' );
    isnt( $res->content, 'this is ignored', 'route return value ignored' );
    is( $res->content, '{"foo":"bar"}', 'Correct content' );
};

done_testing();

