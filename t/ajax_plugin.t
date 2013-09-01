use strict;
use warnings;
use Test::More import => ['!pass'];

{

    package AjaxApp;
    use Dancer2;
    use Dancer2::Plugin::Ajax;

    set plugins => { 'Ajax' => { content_type => 'application/json' } };

    ajax '/test' => sub {
        "{some: 'json'}";
    };

    get '/test' => sub {
        "some text";
    };

    ajax '/another/test' => sub {
        "{more: 'json'}";
    };

}

use Dancer2::Test apps => ['AjaxApp'];

my $r = dancer_response(
    POST => '/test',
    { headers => [ [ 'X-Requested-With' => 'XMLHttpRequest' ], ], }
);
is $r->content, "{some: 'json'}", "ajax works with POST";
is $r->content_type, 'application/json', "Response content type from plugin config";

$r = dancer_response(
    GET => '/test',
    { headers => [ [ 'X-Requested-With' => 'XMLHttpRequest' ], ], }
);
is $r->content, "{some: 'json'}", "ajax works with GET";

$r = dancer_response( POST => '/another/test' );
is $r->status, 404, 'ajax does not match if no XMLHttpRequest';

# GitHub #143 - responst content type not munged if ajax route passes
$r = dancer_response(GET => '/test');
is $r->status, 200, "ajax route passed for an non-XMLHttpRequest";
like $r->content_type, qr{^text/html}, "content type on non-XMLHttpRequest not munged";

done_testing;
