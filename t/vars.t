use strict;
use warnings;
use Test::More import => ['!pass'];

plan tests => 2;

use Dancer2::Test;

{
    use Dancer2;

    hook before => sub {
        var( "xpto" => "foo" );
        vars->{zbr} = 'ugh';
    };

    get '/bar' => sub {
        var("xpto");
    };

    get '/baz' => sub {
        vars->{zbr};
    };
}

response_content_is [ GET => '/bar' ], 'foo';
response_content_is [ GET => '/baz' ], 'ugh';
