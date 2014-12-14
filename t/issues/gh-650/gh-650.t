#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package MyApp;

    use Dancer2;

    set template => 'template_toolkit';

    get '/foo' => sub {
        template 'environment_setting'
    };
    get '/bar' => sub {
        set environment => 'development';
        template 'environment_setting'
    };
}

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    my $res;

    $res = $cb->(GET '/foo');
    is $res->code, 200;
    like $res->content, qr/development/;

    $res = $cb->(GET '/bar');
    is $res->code, 200;
    like $res->content, qr/development/;
};

done_testing();
