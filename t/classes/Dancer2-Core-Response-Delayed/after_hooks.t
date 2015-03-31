use strict;
use warnings;
use Test::More;

use Plack::Test;
use HTTP::Request::Common;
use HTTP::Cookies;

# Tests to ensure a delayed ( but not async ) response
# still have "after" hooks called, such as for session flushing

{
    package App::Delayed;
    use Dancer2;

    set session => 'Simple',

    get '/' => sub {
        session file => __FILE__;
        open my $fh, "<", __FILE__;
        delayed {
            my $responder = $Dancer2::Core::Route::RESPONDER;
            my $res = $Dancer2::Core::Route::RESPONSE;
            return $responder->(
                [ $res->status, $res->headers_to_array, $fh ]
            );
        };
    };

    get '/file' => sub {
        session 'file';
    };

}

my $jar = HTTP::Cookies->new();
my $base = 'http://localhost';

my $test = Plack::Test->create( App::Delayed->to_app );

subtest "delayed (not async) response" => sub {
    my $res = $test->request( GET "$base/" );
    $jar->extract_cookies($res);

    ok $res->is_success, 'Successful request for /';

    open my $fh, "<:raw", __FILE__;
    my $content = do { local $/; <$fh> };
    is $res->content, $content, "response returned test file content";
};

subtest "after hook flushes session headers for delayed response" => sub {
    my $req = GET("$base/file");
    $jar->add_cookie_header($req);

    my $res = $test->request($req);
    $jar->extract_cookies($res);

    ok $res->is_success, 'Successful request for /file';
    is $res->content, __FILE__, "Session returned test file name";
};

done_testing();

