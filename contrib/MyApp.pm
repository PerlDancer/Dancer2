package MyApp;
use strict;
use warnings;
use Dancer;

set serializer => 'JSON';

post '/hello' => sub {
    return { hello => params->{user} };
};
1;
