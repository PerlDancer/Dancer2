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

my @common_tests = (
    [ 'Relative redirect', '/relative', 'expected' ],
    [ 'Relative redirect with ./', '/relative/one-dot', './expected' ],
    [ 'Relative redirect with ../', '/relative/two-dots', '../expected' ],
    [ 'Absolute URL redirect', '/absolute', 'http://expected' ],
    [ 'Schemeless redirect', '/schemeless', '//expected' ],
);

subtest 'Testing app mounted to /' => sub {
    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Redirecting with a leading slash' => sub {
            my $res = $cb->( GET '/leading_slash' );
            is($res->code, 302, 'Correct code');
            is(
                $res->headers->header('Location'),
                '/expected',
                'Correct location header'
            );
        };
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
    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Redirecting with a leading slash' => sub {
            my $res = $cb->( GET '/other-mount-point/leading_slash' );
            is($res->code, 302, 'Correct code');
            is(
                $res->headers->header('Location'),
                '/other-mount-point/expected',
                'Correct location header'
            );
        };
        foreach my $test (@common_tests) {
            my ($name, $url, $expected) = @$test;
            $url = "other-mount-point$url";
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
