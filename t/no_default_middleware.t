use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

use Plack::Middleware::Head;
use Plack::Middleware::FixMissingBodyInRedirect;

# No default middleware wrappers

{
    package MyTestApp;
    use Dancer2;
    set no_default_middleware => 1;

    get '/' => sub { return 'some content' };

    get '/redirect' => sub { redirect '/' };
}


subtest 'Head' => sub {
    my $plain = Plack::Test->create( MyTestApp->to_app );
    my $res = $plain->request( HEAD '/' );
    ok( length( $res->content ) > 0, 'HEAD request on unwrapped app has content' );

    my $test = Plack::Test->create(
        builder {
            enable 'Head';
            MyTestApp->to_app;
        }
    );
    my $response = $test->request( HEAD '/' );
    is( length( $response->content ), 0, 'HEAD request on wrapped app has no content' );

    is( $res->header('Content-Length'),
        $response->header('Content-Length'),
        'HEAD requests have consistent content length header'
    );
};

subtest 'FixMissingBodyInRedirect' => sub {
    my $plain = Plack::Test->create( MyTestApp->to_app );
    my $res = $plain->request( GET '/redirect' );
    is( length( $res->content ), 0, 'GET request that redirects on unwrapped app has no content' );

    my $test = Plack::Test->create(
        builder {
            enable 'FixMissingBodyInRedirect';
            MyTestApp->to_app;
        }
    );
    my $response = $test->request( GET '/redirect' );
    ok( length( $response->content ) > 0, 'GET request that redirects on wrapped app has content' );
};

done_testing;
