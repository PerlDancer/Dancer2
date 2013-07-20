use strict;
use warnings;
use Test::More import => ['!pass'];

{

    package App;
    use Dancer2;
    use Dancer2::Plugin::Ajax;

    ajax '/test' => sub {
        "{some: 'json'}";
    };
}

use Dancer2::Test apps => ['App'];

my $r = dancer_response(
    POST => '/test',
    { headers => [ [ 'X-Requested-With' => 'XMLHttpRequest' ], ], }
);
is $r->content, "{some: 'json'}", "ajax works with POST";

$r = dancer_response(
    GET => '/test',
    { headers => [ [ 'X-Requested-With' => 'XMLHttpRequest' ], ], }
);
is $r->content, "{some: 'json'}", "ajax works with GET";

$r = dancer_response( POST => '/test' );
is $r->status, 404, 'ajax does not match if no XMLHttpRequest';

done_testing;
