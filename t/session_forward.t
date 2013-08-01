use Test::More import => ['!pass'], tests => 1;
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
hook before => sub {
    my $context = shift;
    return if request->path_info =~ m{^/forwarded$};
    session 'value' => 'saved';
    $context->response(forward('/forwarded', undef, undef, $context));
    $context->response->halt;
};

response_content_like ( [ GET => '/' ], qr{saved}, 
    'Session value preserved after forward' );
