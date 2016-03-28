use strict;
use warnings;

use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

{
    package Test::App::SendAs;
    use Dancer2;

    set serializer => 'YAML';
    set template => 'TemplateToolkit';

    get '/html' => sub {
        send_as html => '<html></html>'
    };

    get '/json/**' => sub {
        send_as json => splat;
    };

    get '/json-utf8/**' => sub {
        send_as json => splat, { content_type => 'application/json; charset=utf-8' };
    };

    get '/yaml/**' => sub {
        my @params = splat;
        \@params;
    };

}

my $test = Plack::Test->create( Test::App::SendAs->to_app );

note "default serializer"; {
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

}

note "send_as json"; {
    my $res = $test->request( GET '/json/is/wonderful' );
    is $res->code, '200';
    is $res->content_type, 'application/json';

    is $res->content, '["is","wonderful"]';
}

note "send_as json custom content-type"; {
    my $res = $test->request( GET '/json-utf8/is/wonderful' );
    is $res->code, '200';
    is $res->content_type, 'application/json';
    is $res->content_type_charset, 'UTF-8';

    is $res->content, '["is","wonderful"]';
}


note "send_as html"; {
    my $res = $test->request( GET '/html' );
    is $res->code, '200';
    is $res->content_type, 'text/html';
    is $res->content_type_charset, 'UTF-8';

    is $res->content, '<html></html>';
}

done_testing();
