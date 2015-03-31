use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Dancer2 dsl => 'MyDancerDSL';

envoie '/' => sub {
    request->method;
};

prend '/' => sub {
    proto { ::ok('in proto') }; # no sub!
    request->method;
};


my $test = Plack::Test->create( __PACKAGE__->to_app );

is( $test->request( GET '/' )->content,
    'GET', '[GET /] Correct content'
);
is( $test->request( POST '/' )->content,
    'POST', '[POST /] Correct content'
);

done_testing();
