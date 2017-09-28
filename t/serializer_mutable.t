use strict;
use warnings;

use Dancer2::Serializer::Mutable;
use HTTP::Request::Common;
use Plack::Test;
use Ref::Util qw<is_coderef>;
use Test::More tests => 2;

{

    package MyApp;
    use Dancer2;

    set serializer => 'Mutable';

    post '/' => sub { return request->data };
}

my $app = MyApp->to_app;
ok is_coderef($app), 'Got app';

test_psgi $app, sub {
    my $cb = shift;

    # Configure all test cases
    my @tests = (
        {   name                  => "simple",
            request_header        => {'Content-Type' => 'application/json'},
            request_body          => q<{"foo":"bar"}>,
            response_content_type => 'application/json',
            response_body         => q<{"foo":"bar"}>,
        },
    );

    for my $test (@tests) {
        subtest $test->{name} => sub {

            # Test getting the value serialized in the correct format
            my $res = $cb->(
                POST '/',
                %{$test->{request_header}},
                content => $test->{request_body}
            );

            is $res->code, 200, "response status code";
            is $res->headers->content_type => $test->{response_content_type},
              "response content type";
            is $res->content, $test->{response_body}, "response content";
        };
    }
};
