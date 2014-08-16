use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common qw(GET HEAD PUT POST DELETE);

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

    ajax ['put', 'del', 'get'] => "/more/test" => sub {
        "{some: 'json'}";
    };
}

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    {
        my $res = $cb->(
            POST '/test', 'X-Requested-With' => 'XMLHttpRequest'
        );

        is( $res->content, q({some: 'json'}), 'ajax works with POST' );
        is( $res->content_type, 'application/json', 'ajax content type' );
    }

    {
        my $res = $cb->( GET '/test', 'X-Requested-With' => 'XMLHttpRequest' );
        is( $res->content, q({some: 'json'}), 'ajax works with GET' );
    }

    {
        my $res = $cb->( GET '/more/test', 'X-Requested-With' => 'XMLHttpRequest' );
        is( $res->content, q({some: 'json'}), 'ajax works with GET on multi-method route' );
    }

    {
        my $res = $cb->( PUT '/more/test', 'X-Requested-With' => 'XMLHttpRequest' );
        is( $res->content, q({some: 'json'}), 'ajax works with PUT on multi-method route' );
    }

    {
        my $res = $cb->( DELETE '/more/test', 'X-Requested-With' => 'XMLHttpRequest' );
        is( $res->content, q({some: 'json'}), 'ajax works with DELETE on multi-method route' );
    }

    {
        my $res = $cb->( POST '/more/test', 'X-Requested-With' => 'XMLHttpRequest' );
        is( $res->code, 404, 'ajax multi-method route only valid for the defined routes' );
    }

    {
        is(
            $cb->( POST '/another/test' )->code,
            404,
            'ajax route passed for non-XMLHttpRequest',
        );
    }

    {
        # GitHub #143 - response content type not munged if ajax route passes
        my $res = $cb->( GET '/test' );

        is(
            $res->code,
            200,
            'ajax route passed for non-XMLHttpRequest',
        );

        is(
            $res->content,
            'some text',
            'ajax route has proper content for GET without XHR',
        );

        is(
            $res->content_type,
            'text/html',
            'content type on non-XMLHttpRequest not munged',
        );
    }
};

done_testing;
