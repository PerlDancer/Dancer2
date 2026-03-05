#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

# Test to ensure that a longjump out of a template, caused by a call to redirect,
# does not cause any future problems rendering a template. Whilst this test is
# slightly obscure for reasons of simplicity, the exact use-case is in the use
# of Plugin::LogReport. If it catches a fatal error (which could occur during
# the render of a template) then it will redirect to another page.

{
    package MyApp;

    use Dancer2;

    set template => 'template_toolkit';

    # Set up 2 routes to the same template. The first route will redirect when
    # the template renders, the second will not
    get '/redirect' => sub {
        my $redir = sub {
            redirect "somewhere";
        };
        template 'redirect',
            { redirect_sub => $redir }
    };

    get '/noredirect' => sub {
        template 'redirect';
    };
}

my $app = Dancer2->psgi_app;
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET '/redirect');
    is $res->code, 302, 'Redirect template results in redirect';

    $res = $cb->(GET '/noredirect');
    is $res->code, 200, 'Successful subsequent request to normal template';
    like $res->content, qr/foobar/, 'Correct content';
};

done_testing();
