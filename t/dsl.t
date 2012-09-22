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
    is $r->content, 'GET';
}

{
    my $r = dancer_response POST => '/';
    is $r->content, 'POST';
}

is int(dancer_version), 2, 'dancer_version';
done_testing;
