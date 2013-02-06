use Test::More import => ['!pass'], tests => 1;
use Dancer 2.0 ':syntax';
use Dancer::Test;
use strict;
use warnings;


get '/' => sub {
    return 'Forbidden';
};

get '/default' => sub {
    return 'Default';
};

hook before => sub {
    request->path_info('/default');
};

response_content_like ( [ GET => '/' ], qr{Default}, 
    'Changing request->path_info worked' );

done_testing();
