use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

subtest 'request data basic' => sub {
    {
        package App::Body::Str; ## no critic
        use Dancer2;

        post '/' => sub {
            my $data = request_data;
            ::is(
                $data,
                'a string body',
                'string content ok'
            );
        };
    }

    my $app = Plack::Test->create( App::Body::Str->to_app );
    my $res = $app->request( POST '/', Content_Type => 'text/plain', Content => "a string body" );
    ok( $res->is_success, 'Successful request' );
};

subtest 'request data serialized' => sub {
    {
        package App::Body::JSON; ## no critic
        use Dancer2;

        set serializer => 'JSON';

        post '/' => sub {
            my $data = request_data;
            ::is_deeply(
                $data,
                { body => { is => [ "json" ] } },
                'json content ok'
            );

            return +{ ok => 1 };
        };
    }

    my $app = Plack::Test->create( App::Body::JSON->to_app );
    my $res = $app->request( POST '/', Content_Type => 'application/json', Content => '{"body":{"is":["json"]}}' );
    ok( $res->is_success, 'Successful request' );
};

done_testing();
