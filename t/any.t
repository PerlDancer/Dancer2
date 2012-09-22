use strict;
use warnings;
use Test::More import => ['!pass'];

{
    package App;
    use Dancer;

    any [ 'get', 'post' ] => '/test' => sub {
        request->method;
    };
}

use Dancer::Test 'App';

my $r = dancer_response( POST => '/test' );
is $r->content, 'POST';

$r = dancer_response( GET => '/test' );
is $r->content, 'GET';
     
done_testing;
