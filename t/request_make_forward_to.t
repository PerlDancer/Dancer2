use strict;
use warnings;
use Test::More tests=>1;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;

{

    package ContentLengthTestApp;
    use Dancer2;
    set serializer => 'JSON';

    post '/foo' => sub {
        forward('/not_authorized');
    };

    any '/not_authorized' => sub {
        status 401;
        { access => 'denied' };
    };
}

{
    my $url  = 'http://localhost';
    my $test = Plack::Test->create( ContentLengthTestApp->to_app );

    my $response = $test->request(
        POST(
            '/foo',
            Content =>
                encode_json( { target => [ 'foo', 'bar' ] } ),
        )
    );

    is( $response->code, 401, 'Access denied to unauthorized merge' );

}
