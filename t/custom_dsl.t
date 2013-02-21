use strict;
use warnings;
use Test::More import => ['!pass'];

use FindBin qw($Bin);
use lib "$Bin/t/lib";
use Dancer2 dsl => 'MyDancerDSL';
use Dancer2::Test;


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
