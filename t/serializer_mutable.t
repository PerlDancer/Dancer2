use strict;
use warnings;

use Dancer2::Serializer::Mutable;
use HTTP::Request::Common;
use Plack::Test;
use Test::More tests => 10;

{

    package MyApp;
    use Dancer2;

    our $data = {foo => "bar"};
    our $return = \$data;

    set serializer => 'Mutable';

    post '/' => sub {
        Test::More::is_deeply request->data => $data,
          "request->data"
          or Test::More::explain(Test::More::explain request->data);
        return $$return;
    };
}

isa_ok my $app = MyApp->to_app => 'CODE', "app";

use Plack::Middleware::TrafficLog;
$app = Plack::Middleware::TrafficLog->wrap(
    $app,
    logger => sub { return; warn "@_" },
    with_body => 1,    # TODO find out why this fixes the test
);

subtest support_content_type => sub {
    ok my $serializer = Dancer2::Serializer::Mutable->new,
      "Dancer2::Serializer::Mutable->new";

    ok $serializer->support_content_type('application/json'),
      "supports content type application/json";

    ok $serializer->support_content_type('application/json; charset=utf8'),
      "supports content type with parameters";

    ok !$serializer->support_content_type('text/example'),
      "doesn't support bogus content type";

    ok !$serializer->support_content_type(undef),
      "doesn't support undefined value";
};

my $yaml = <<YAML;
---
foo: bar
YAML

# do not use JSON for test cases because JSON is fallback for serialization
my @tests = (
    {   name           => "equal 'Content-Type' and 'Accept' header",
        request_header => {
            'Content-Type' => 'text/x-yaml',
            'Accept'       => 'text/x-yaml',
        },
        request_body          => $yaml,
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {   name                  => "only 'Content-Type' header",
        request_header        => {'Content-Type' => 'text/x-yaml'},
        request_body          => $yaml,
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {   name                  => "only 'Accept' header",
        request_header        => {'Accept' => 'text/x-yaml'},
        request_body          => $yaml,
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {    # https://tools.ietf.org/html/rfc7231#section-5.3.2
        name                  => "'Accept' header with media range",
        request_header        => {'Accept' => 'text/example, text/x-yaml'},
        request_body          => $yaml,
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {   name           => "different 'Content-Type' and 'Accept' header",
        request_header => {
            'Content-Type' => 'text/x-data-dumper',
            'Accept'       => 'text/x-yaml',
        },
        request_body          => '$VAR1 = { "foo" => "bar" };',
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {   name => "unsupported 'Content-Type' and supported 'Accept' header",
        before =>
          sub { $MyApp::data = undef; $MyApp::return = \{foo => 'bar'} },
        request_header => {
            'Content-Type' => 'text/example',
            'Accept'       => 'text/x-yaml',
        },
        request_body          => 'string',
        response_content_type => 'text/x-yaml',
        response_body         => $yaml,
    },
    {   name   => "no header, string returned",
        before => sub { $MyApp::data = undef; $MyApp::return = \'string' },
        request_body          => 'foo bar',
        response_content_type => 'text/html',
        response_body         => 'string',
    },
    {   name => "no header, hashref returned",
        before =>
          sub { $MyApp::data = undef; $MyApp::return = \{foo => 'bar'} },
        request_body          => 'foo bar',
        response_content_type => 'application/json',    # fallback
        response_body         => '{"foo":"bar"}',
    },
);

test_psgi $app, sub {
    my $cb = shift;

    for my $test (@tests) {
        subtest $test->{name} => sub {
            $test->{before} and $test->{before}->();

            my $req = POST(
                '/',
                %{$test->{request_header}},
                content => $test->{request_body}
            );

            # remove default value for Content-Type
            $test->{request_header}{'Content-Type'}
              or $req->remove_header('Content-Type');

            my $res = $cb->($req);
            is $res->code => 200, "response status code";

            if ($test->{response_content_type}) {
                is $res->headers->content_type =>
                  $test->{response_content_type},
                  "response content type";
            }
            else {
                ok $res->headers->content_type,
                  "response content type is defined";
            }

            if (ref $test->{response_body} eq 'Regexp') {
                like $res->content => $test->{response_body},
                  "response content";
            }
            else {
                is $res->content => $test->{response_body}, "response content";
            }
        };
    }
};
