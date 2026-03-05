#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;

BEGIN{
  # undefine ENV vars used as defaults for app environment in these tests
  delete $ENV{DANCER_ENVIRONMENT};
  delete $ENV{PLACK_ENV};
}

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
ok( is_coderef($app), 'Got app' );

test_psgi $app, sub {
    my $cb = shift;
    my $res;

    $res = $cb->(GET '/foo');
    is $res->code, 200, 'Successful request';
    like $res->content, qr/development/, 'Correct content';

    $res = $cb->(GET '/bar');
    is $res->code, 200, 'Successful request';
    like $res->content, qr/development/, 'Correct content';
};

done_testing();
