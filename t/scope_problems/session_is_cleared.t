#!/usr/bin/env perl

## This test will first cause a (legitimate) error in a
## before_template_render hook
## Then it will fetch an unrelated route that should return normally.
## However, this route is now using the wrong with_return block.
## This is because the first route, errors in rendering the *error* page.
## This cause the block to die, and with_return is never unset.
## This test uses two template files 

package MyTestApp;
use Dancer2;

hook before_template_render => sub {
    my $path = request->path;
    if ( $path =~ m!route_with_renderer_error! ) {
        die session->id;
    }
};

get '/route_with_renderer_error' => sub {
    ## This route first gets called, then template fires the above hook.
    ## This hook errors, causing Dancer2::Core::App, to throw an error
    ## which *also* fires the hook, crashing the server.
    session->write('bob' => "I SHOULD NOT BE IN THE NEXT SESSION");
    my $tt = session->id;
    template \"$tt";
};

get '/normal_route' => sub {
    ## This should issue normally
    if ( !session('bob') ) {
        session('bob' => "test" . rand());
    }
    return session('bob');
};

package main;
use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common qw/GET/;
use Dancer2;

my $test = Plack::Test->create(Dancer2->psgi_app);

## This route works fine
## Just a sanity check
my $res1 = $test->request(GET '/normal_route');
ok($res1->is_success, '/normal_route does not error');

## This route should die and cause a broken state
my $res2 = $test->request(GET '/route_with_renderer_error');
ok(! $res2->is_success, '/route_with_renderer_error errors errors');

## This route will now have the same session as the previous route.
## Despite not having any cookies...
my $res3 = $test->request(GET '/normal_route');
ok($res3->is_success, '/normal_route does not error');
my $session_value = $res3->decoded_content;
isnt($session_value, "I SHOULD NOT BE IN THE NEXT SESSION", 
    '3rd route does not have session value from second route');

done_testing();
