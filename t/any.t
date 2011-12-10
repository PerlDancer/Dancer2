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
is $r->[2][0], 'POST';

$r = dancer_response( GET => '/test' );
is $r->[2][0], 'GET';
     
done_testing;
