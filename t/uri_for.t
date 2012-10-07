use Test::More import => ['!pass'];
use strict;
use warnings;

{
    use Dancer;
    get '/foo' => sub {
        return uri_for('/foo');
    };
}

use Dancer::Test;
response_status_is [GET => '/foo'], 200;

response_content_is [GET => '/foo'],
    'http://localhost/foo',
    "uri_for works as expected";

done_testing;
