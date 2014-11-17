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
use Scalar::Util qw/refaddr/;

hook before_template_render => sub {
    my $path = request->path;
    my $refadd = refaddr(app->with_return);
    if ( $path =~ m!route_with_renderer_error! ) {
        die $refadd;
    }
};

get '/route_with_renderer_error' => sub {
    ## This route first gets called, then template fires the above hook.
    ## This hook errors, causing Dancer2::Core::App, to throw an error
    ## which *also* fires the hook, crashing the server.
    my $addr = refaddr(app->with_return);
    template \$addr;
};

get '/normal_route' => sub {
    ## This should issue normally
    # my $addr = refaddr(app->with_return);
    # template \$addr;
    return refaddr(app->with_return);
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
my $res1 = $test->request(GET '/normal_route');
ok($res1->is_success, '/normal_route does not error');
my $refaddr1 = $res1->decoded_content;

## This route should die
my $res2 = $test->request(GET '/route_with_renderer_error');
ok(! $res2->is_success, '/route_with_renderer_error errors errors');
my ($refaddr2) = $res2->decoded_content =~ /Hook error: (\d+)/;

## The first route now errors
## I can't seem to force with_return to fail in this test, even though I have
## it failing in production.
## So instead I'll check the refaddr of the with_return
## If refaddr of with_return is the same between route2 and route3, then this
## demonstrates that with_return has not been cleared between the two routes
## And that /normal_route is now using the wrong with_return.
## Possibly the old with_return hasn't been cleaned up? not sure.
my $res3 = $test->request(GET '/normal_route');
ok($res3->is_success, '/normal_route does not error');
my $refaddr3 = $res3->decoded_content;
isnt($refaddr1, $refaddr3, 'The 3rd request has a different with_return from the first run');
isnt($refaddr2, $refaddr3, 'The 3rd request has a different with_return from the second run');

done_testing();
