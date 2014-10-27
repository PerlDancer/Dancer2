use strict;
use warnings;

use Test::More tests => 18;
use Plack::Test;
use HTTP::Request::Common;
use Dancer2::Logger::Capture;

my $logger = Dancer2::Logger::Capture->new;
isa_ok( $logger, 'Dancer2::Logger::Capture' );

{

    package MyApp;

    use Dancer2;

    set serializer => 'JSON';

    put '/from_params' => sub {
        my %p = params();
        return join " : ", map { $_ => $p{$_} } sort keys %p;
    };

    put '/from_data' => sub {
        my $p = request->data;
        return join " : ", map { $_ => $p->{$_} } sort keys %$p;
    };

    # This route is used for both toure and body params.
    post '/from/:town' => sub {
        my $p = params;
        return $p;
    };

    any [qw/del patch/] => '/from/:town' => sub {
        my $p = params('body');
        return $p;
    };
}

my $app = MyApp->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    foreach my $type ( qw<params data> ) {
        is(
            $cb->(
                PUT '/from_params',
                    'Content-Type' => 'application/json',
                    Content        => '{ "foo": 1, "bar": 2 }'
            )->content,
            'bar : 2 : foo : 1',
            "Using $type",
        )
    }
};


use utf8;
use JSON;
use Encode;
use Class::Load 'load_class';

note "Verify Serializers decode into characters"; {
    my $utf8 = '∮ E⋅da = Q,  n → ∞, ∑ f(i) = ∏ g(i)';

    test_psgi $app, sub {
        my $cb = shift;

        for my $type ( qw/Dumper JSON YAML/ ) {
            my $class = "Dancer2::Serializer::$type";
            load_class($class);

            my $serializer = $class->new();
            my $body = $serializer->serialize({utf8 => $utf8});

            # change the app serializer
            # we're overiding a RO attribute only for this test!
            Dancer2->runner->apps->[0]->set_serializer_engine(
                $serializer
            );

            my $r = $cb->(
                PUT '/from_params',
                    'Content-Type' => $serializer->content_type,
                    Content        => $body,
            );

            my $content = Encode::decode( 'UTF-8', $r->content );
            is(
                $content,
                "utf8 : $utf8",
                "utf-8 string returns the same using the $type serializer",
            );
        }
    };
}

# default back to JSON for the rest
# we're overiding a RO attribute only for this test!
Dancer2->runner->apps->[0]->set_serializer_engine(
    Dancer2::Serializer::JSON->new
);

note "Decoding of mixed route and deserialized body params"; {
    # Check integers from request body remain integers
    # but route params get decoded.
    test_psgi $app, sub {
        my $cb = shift;

        my @req_params = (
            "/from/D\x{c3}\x{bc}sseldorf", # /from/d%C3%BCsseldorf
            'Content-Type' => 'application/json',
            Content        => JSON::to_json({ population => 592393 }),
        );

        my $r       = $cb->( POST @req_params );
        my $content = Encode::decode( 'UTF-8', $r->content );

        # Watch out for hash order randomization..
        like(
            $content,
            qr/[{,]"population":592393/,
            "Integer from JSON body remains integer",
        );

        like(
            $content,
            qr/[{,]"town":"Düsseldorf"/,
            "Route params are decoded",
        );
    };
}

# Check body is deserialized on PATCH and DELETE.
# The RFC states the behaviour for DELETE is undefined; We take the lenient
# and deserialize it.
# http://tools.ietf.org/html/draft-ietf-httpbis-p2-semantics-24#section-4.3.5
note "Deserialze any body content that is allowed or undefined"; {
    test_psgi $app, sub {
        my $cb = shift;

        for my $method ( qw/delete patch/ ) {
            my $request  = HTTP::Request->new(
                $method,
                "/from/D\x{c3}\x{bc}sseldorf", # /from/d%C3%BCsseldorf
                [ 'Content-Type' => 'application/json' ],
                JSON::to_json({ population => 592393 }),
            );
            my $response = $cb->($request);
            my $content  = Encode::decode( 'UTF-8', $response->content );

            # Only body params returned
            is(
                $content,
                '{"population":592393}',
                "JSON body deserialized for " . uc($method) . " requests",
            );
        }
    }
}

note 'Check serialization errors'; {
    Dancer2->runner->apps->[0]->set_serializer_engine(
        Dancer2::Serializer::JSON->new( logger => $logger )
    );

    test_psgi $app, sub {
        my $cb = shift;

        $cb->(
            PUT '/from_params',
                'Content-Type' => 'application/json',
                Content        => '---',
        );

        my $trap = $logger->trapper;
        isa_ok( $trap, 'Dancer2::Logger::Capture::Trap' );

        my $errors = $trap->read;
        isa_ok( $errors, 'ARRAY' );
        is( scalar @{$errors}, 1, 'One error caught' );

        my $msg = $errors->[0];
        isa_ok( $msg, 'HASH' );
        is( scalar keys %{$msg}, 2, 'Two items in the error' );

        is( $msg->{'level'}, 'core', 'Correct level' );
        like(
            $msg->{'message'},
            qr{
                ^
                \QFailed to deserialize the request: \E
                \Qmalformed number\E
            }x,
            'Correct error message',
        );
    }
}

