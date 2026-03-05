#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

# Tests for obscure rendering situations that may occur whilst undertaking
# template processing

{
    package MyApp;

    use Dancer2;

    set template => 'template_toolkit';

    hook on_route_exception => sub {
        status 200;
            send_as(plain => "Some plain text");
    };

    get '/bork' => sub {
        my $bork = sub {
            die "I've borked in the template";
        };
        template 'exec',
            { exec_sub => $bork }
    };

    get '/plain' => sub {
        my $plain = sub {
            send_as(plain => "Some plain text");
        };
        template 'exec',
            { exec_sub => $plain }
    };

    get '/html' => sub {
        my $html = sub {
            send_as(html => "<p>HTML text</p>");
        };
        template 'exec',
            { exec_sub => $html }
    };
}

my $app = Dancer2->psgi_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    my $res = $cb->(GET '/bork');
    is $res->code, 200, 'Correct status code when overriding exception handling';
    like $res->content, qr/plain text/, 'Correct content when overriding exception handling';

    $res = $cb->(GET '/plain');
    is $res->code, 200, 'Correct status when sending as plain during template render';
    like $res->content, qr/plain text/, 'Correct content when sending as plain';

    $res = $cb->(GET '/html');
    is $res->code, 200, 'Correct status when sending as HTML during template render';
    like $res->content, qr/HTML text/, 'Correct content when sending as HTML';
};

done_testing();
