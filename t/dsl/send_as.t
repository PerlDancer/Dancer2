use strict;
use warnings;

use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

{
    package Test::App::SendAs;
    use Dancer2;

    set logger => 'Capture';
    set serializer => 'YAML';
    set template => 'TemplateToolkit';

    get '/html' => sub {
        send_as html => '<html></html>'
    };

    get '/json/**' => sub {
        send_as JSON => splat;
    };

    get '/json-utf8/**' => sub {
        send_as JSON => splat, { content_type => 'application/json', charset => 'utf-8' };
    };

    get '/yaml/**' => sub {
        my @params = splat;
        \@params;
    };

    get '/sendas/:type?' => sub {
        send_as route_parameters->{'type'} => 'test string';
    };
}

my $test = Plack::Test->create( Test::App::SendAs->to_app );

subtest "default serializer" => sub {
    my $res = $test->request( GET '/yaml/is/useful' );
    is $res->code, '200';
    is $res->content_type, 'text/x-yaml';

    my $expected = <<'YAML';
---
-
  - is
  - useful
YAML

    is $res->content, $expected;

};

subtest "send_as json" => sub {
    my $res = $test->request( GET '/json/is/wonderful' );
    is $res->code, '200';
    is $res->content_type, 'application/json';

    is $res->content, '["is","wonderful"]';
};

subtest "send_as json custom content-type" => sub {
    my $res = $test->request( GET '/json-utf8/is/wonderful' );
    is $res->code, '200';
    is $res->content_type, 'application/json';
    is $res->content_type_charset, 'UTF-8';

    is $res->content, '["is","wonderful"]';
};


subtest "send_as html" => sub {
    my $res = $test->request( GET '/html' );
    is $res->code, '200';
    is $res->content_type, 'text/html';
    is $res->content_type_charset, 'UTF-8';

    is $res->content, '<html></html>';
};

subtest "send_as error cases" => sub {
    my $logger = Test::App::SendAs::app->logger_engine;

    {
        my $res = $test->request( GET '/sendas/' );
        is $res->code, '500', "send_as dies with no defined type";

        my $logs = $logger->trapper->read;
        like $logs->[0]->{message},
             qr!Route exception: Can not send_as using an undefined type!,
             ".. throws route exception";
    }

    {
        my $res = $test->request( GET '/sendas/jSoN' );
        is $res->code, '500',
            "send_as dies with incorrectly cased serializer name";

        my $logs = $logger->trapper->read;
        like $logs->[0]->{message},
             qr!Route exception: Unable to load serializer class for jSoN!,
             ".. throws route exception";
    }

    {
        my $res = $test->request( GET '/sendas/SomeSerializerThatDoesNotExist' );
        is $res->code, '500',
            "send_as dies when called with non-existant serializer";

        my $logs = $logger->trapper->read;
        like $logs->[0]->{message},
             qr!Route exception: Unable to load serializer class for SomeSerializerThatDoesNotExist!,
             ".. throws route exception";
    }
};

done_testing();
