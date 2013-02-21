use strict;
use warnings;
use Test::More import => ['!pass'];

use Dancer2;
use Dancer2::Test;

get '/' => sub {
    'home:' . join(',', params);
};
get '/bounce/' => sub {
    return forward '/';
};
get '/bounce/:withparams/' => sub {
    return forward '/';
};
get '/bounce2/adding_params/' => sub {
    return forward '/', {withparams => 'foo'};
};
post '/simple_post_route/' => sub {
    'post:' . join(',', params);
};
get '/go_to_post/' => sub {
    return forward '/simple_post_route/', {foo => 'bar'}, {method => 'post'};
};

# NOT SUPPORTED IN DANCER2
# In dancer2, vars are alive for only one request flow, a forward initiate a
# new request flow, then the vars HashRef is destroyed.
#
# get '/b' => sub { vars->{test} = 1;  forward '/a'; };
# get '/a' => sub { return "test is " . var('test'); };

response_status_is  [GET => '/'] => 200;
response_content_is [GET => '/'] => 'home:';

response_status_is  [GET => '/bounce/'] => 200;
response_content_is [GET => '/bounce/'] => 'home:';

response_status_is [GET => '/bounce/thesethings/'] => 200;
response_content_is [GET => '/bounce/thesethings/'] =>
  'home:withparams,thesethings';

response_status_is [GET => '/bounce2/adding_params/'] => 200;
response_content_is [GET => '/bounce2/adding_params/'] =>
  'home:withparams,foo';

response_status_is  [GET => '/go_to_post/'] => 200;
response_content_is [GET => '/go_to_post/'] => 'post:foo,bar';

# NOT SUPPORTED
# response_status_is  [ GET => '/b' ] => 200;
# response_content_is [ GET => '/b' ] => 'test is 1';

my $expected_headers = [
    'Content-Length' => 5,
    'Content-Type'   => 'text/html; charset=UTF-8',
    'Server'         => "Perl Dancer2 $Dancer2::VERSION",
];

response_headers_are_deeply [GET => '/bounce/'], $expected_headers;

# checking post

post '/'        => sub {'post-home'};
post '/bounce/' => sub { forward('/') };

response_status_is  [POST => '/'] => 200;
response_content_is [POST => '/'] => 'post-home';

response_status_is  [POST => '/bounce/'] => 200;
response_content_is [POST => '/bounce/'] => 'post-home';

$expected_headers->[1] = 9;
response_headers_are_deeply [POST => '/bounce/'], $expected_headers;

done_testing;
