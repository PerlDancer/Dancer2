use Test::More import => ['!pass'], tests => 1;
use Dancer2;
use Dancer2::Test;
use strict;
use warnings;

set session => 'Simple';

get '/set_session' => sub {
    session 'foo' => 'bar';
    forward '/get_session';
};

get '/get_session' => sub {
    session 'foo'
};

response_content_is( [ GET => '/set_session' ], q{bar},
                     'Session value preserved after forward from route' );
