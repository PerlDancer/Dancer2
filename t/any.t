use strict;
use warnings;
use Test::More import => ['!pass'];

{

    package App;
    use Dancer;

    any ['get', 'post'] => '/test' => sub {
        request->method;
    };

    any '/all' => sub {
        request->method;
    };
}

use Dancer::Test apps => ['App'];

my $r = dancer_response(POST => '/test');
is $r->content, 'POST';

$r = dancer_response(GET => '/test');
is $r->content, 'GET';

for my $method (qw(GET HEAD POST PUT DELETE OPTIONS PATCH)) {
    my $r = dancer_response($method => '/all');
    is $r->content, $method;
}

done_testing;
