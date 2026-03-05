use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use utf8;
use Encode qw();

{
    package Test::Forward::HMV;
    use Dancer2;

    any '/' => sub {
        'home:' . join( ',', request->parameters->flatten );
    };

    get '/get' => sub {
        forward '/', { get => 'bâz' };
    };

    post '/post' => sub {
        forward '/', { post => 'bâz' };
    };

    post '/change/:me' => sub {
        forward '/', { post => route_parameters->get('me') }, { method => 'GET' };
    };
}

my $test = Plack::Test->create( Test::Forward::HMV->to_app );

subtest 'query parameters (#1245)' => sub {
    my $res = $test->request( GET '/get?foo=bâr' );
    is $res->code, 200, "success forward for /get";
    my $content = Encode::decode( 'UTF-8', $res->content );
    is $content, 'home:foo,bâr,get,bâz', "query parameters merged after forward";
};

subtest 'body parameters (#1116)' => sub {
    my $res = $test->request( POST '/post', { foo => 'bâr' } );
    is $res->code, 200, "success forward for /post";
    # The order is important: post,baz are QUERY params
    # foo,bar are the original body params
    my $content = Encode::decode( 'UTF-8', $res->content );
    like $content, qr/^home:post,bâz/, "forward params become query params";
    is $content, 'home:post,bâz,foo,bâr', "body parameters available after forward";
};

subtest 'params when method changes' => sub {
    my $res = $test->request( POST '/change/1234', { foo => 'bâr' } );
    is $res->code, 200, "success forward for /change/:me";
    my $content = Encode::decode( 'UTF-8', $res->content );
    is $content, 'home:post,1234,foo,bâr', "body parameters available after forward";
};

done_testing();
