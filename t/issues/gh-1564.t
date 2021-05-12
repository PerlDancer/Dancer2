#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    get '/root' => sub { redirect '/'; };
    get '/leading_slash' => sub { redirect '/expected'; };
    get '/relative' => sub { redirect 'expected'; };
    get '/relative/one-dot' => sub { redirect './expected'; };
    get '/relative/two-dots' => sub { redirect '../expected'; };
    get '/absolute' => sub { redirect 'http://expected' };
    get '/schemeless' => sub { redirect '//expected' };
}

my $app = builder {
    mount '/' => App->to_app();
    mount '/other-mount-point' => App->to_app();
};

my @leading_slash_tests = (
    # the expected result (last element) needs the mount prepended in the actual tests
    [ 'Relative with leading slash', '/leading_slash', '/expected' ],
    [ 'Relative root', '/root', '/' ],  # Test for issue #1611
);

my @common_tests = (
    [ 'Relative redirect', '/relative', 'expected' ],
    [ 'Relative redirect with ./', '/relative/one-dot', './expected' ],
    [ 'Relative redirect with ../', '/relative/two-dots', '../expected' ],
    [ 'Absolute URL redirect', '/absolute', 'http://expected' ],
    [ 'Schemeless redirect', '/schemeless', '//expected' ],
);

subtest 'Testing app mounted to /' => sub {
    my $mount = '';

    test_psgi $app, sub {
        my $cb = shift;

        for my $test (@leading_slash_tests) {
            my ($name, $url, $expected) = @$test;
            subtest $name => sub {
                my $res = $cb->( GET $url );
                is($res->code, 302, 'Correct code');
                is(
                    $res->headers->header('Location'),
                    $mount . $expected,
                    'Correct location header'
                );
            }
        }

        foreach my $test (@common_tests) {
            my ($name, $url, $expected) = @$test;
            subtest $name => sub {
                my $res = $cb->( GET $url );
                is($res->code, 302, 'Correct code');
                is(
                    $res->headers->header('Location'),
                    $expected,
                    'Correct location header'
                );
            }
        }
    };
};

subtest 'Testing app mounted to /other-mount-point' => sub {
    my $mount = '/other-mount-point';

    test_psgi $app, sub {
        my $cb = shift;

        for my $test (@leading_slash_tests) {
            my ($name, $url, $expected) = @$test;
            $url = "$mount$url";
            subtest $name => sub {
                my $res = $cb->( GET $url );
                is($res->code, 302, 'Correct code');
                is(
                    $res->headers->header('Location'),
                    "$mount$expected",  # scriptname prepended to redirect path
                    'Correct location header'
                );
            }
        }

        foreach my $test (@common_tests) {
            my ($name, $url, $expected) = @$test;
            $url = "$mount$url";
            subtest $name => sub {
                my $res = $cb->( GET $url );
                is($res->code, 302, 'Correct code');
                is(
                    $res->headers->header('Location'),
                    $expected,
                    'Correct location header'
                );
            }
        }
    };
};

note 'DONE!';
