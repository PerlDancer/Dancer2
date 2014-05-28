#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use LWP::UserAgent;

eval "use LWP::Protocol::PSGI";
plan skip_all => "LWP::Protocol::PSGI is needed for this test" if $@;

plan tests => 5;

my $psgi_app = do {
    use Dancer2;

    set apphandler => 'PSGI';

    get '/search' => sub {
        my $q = param('q');
        is( $q, 'foo', 'Correct parameter to Google' );
        return 'bar';
    };

    dance;
};

# Register the $psgi_app to handle all LWP requests
LWP::Protocol::PSGI->register($psgi_app); 
my $ua  = LWP::UserAgent->new;
isa_ok( $ua, 'LWP::UserAgent' );

my $res = $ua->get("http://www.google.com/search?q=foo");
isa_ok( $res, 'HTTP::Response' );

ok( $res->is_success, 'Request is successful' );
is( $res->content, 'bar', 'Correct response content' );

