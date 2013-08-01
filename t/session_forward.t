use Test::More import => ['!pass'], tests => 2;
use Dancer2;
use Dancer2::Test;
use strict;
use warnings;

set session => 'Simple';

get '/' => sub {
    return 'Wrong place';
};

get '/forwarded' => sub {
    return session('value');
};

# hook before => sub {
#     my $context = shift;
#     return if request->path_info =~ m{^/forwarded$};
#     session 'value' => 'saved';
#     $context->response(forward('/forwarded', undef, undef, $context));
#     $context->response->halt;
# };

get '/set_session' => sub {
    session 'foo' => 'bar';
    forward '/get_session';
};

get '/get_session' => sub {
    session 'foo'
};

# response_content_is ( [ GET => '/' ], q{saved},
#                       'Session value preserved after forward from hook' );

response_content_is( [ GET => '/set_session' ], q{bar},
                     'Session value preserved after forward from route' );
