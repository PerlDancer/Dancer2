use Test::More import => ['!pass'], tests => 2;
use Dancer2;
use Dancer2::Test;
use strict;
use warnings;

set session => 'Simple';

get '/set_chained_session' => sub {
    session 'zbr' => 'ugh';
    forward '/set_session';
};

get '/set_session' => sub {
    session 'foo' => 'bar';
    forward '/get_session';
};

get '/get_session' => sub {
    sprintf("%s:%s", session('foo') , session('zbr')||"")
};

get '/clear' => sub {
    session "foo" => undef;
    session "zbr" => undef;
};


response_content_is( [ GET => '/set_chained_session' ], q{bar:ugh},
                     'Session value preserved after chained forwards' );

dancer_response( GET => '/clear');


response_content_is( [ GET => '/set_session' ], q{bar:},
                     'Session value preserved after forward from route' );
