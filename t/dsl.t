use strict;
use warnings;
use Test::More import => [ '!pass' ];

use Dancer;
use Dancer::Test;

any ['get', 'post'], '/'  => sub { 
    request->method;
};

{
    my $r = dancer_response GET => '/';
    is $r->[2][0], 'GET';
}

{
    my $r = dancer_response POST => '/';
    is $r->[2][0], 'POST';
}

is dancer_major_version, 2, 'dancer_major_version';
done_testing;
