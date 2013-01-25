use strict;
use warnings;
use Test::More import => ['!pass'];

use FindBin qw($Bin);
use lib "$Bin/t/lib";
use Dancer dsl => 'MyDancerDSL';
use Dancer::Test;


envoie '/' => sub {
    request->method;
};

prend '/' => sub {
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

done_testing;
