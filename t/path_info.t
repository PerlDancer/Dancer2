use Test::More import => ['!pass'], tests => 1;
use Dancer2;
use Dancer2::Test;
use strict;
use warnings;


get '/' => sub {
    return 'Forbidden';
};

get '/default' => sub {
    return 'Default';
};

hook before => sub {
    my $context = shift;
    return if $context->request->path eq '/default';

    $context->response( forward('/default') );
    $context->response->halt;
};

response_content_like ( [ GET => '/' ], qr{Default}, 
    'Changing request->path_info worked' );

done_testing();
