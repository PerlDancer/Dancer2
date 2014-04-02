use strict;
use warnings;

use Test::More tests => 10;
use Plack::Test;
use HTTP::Request::Common;

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

    post '/from/:town' => sub {
        my $p = params;
        return $p;
    };
}

my $app = Dancer2->runner->server->psgi_app;
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
            Dancer2->runner->server->apps->[0]->engines->{'serializer'} =
                $serializer;

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

note "Decoding of mixed route and deserialized body params"; {
    # Check integers from request body remain integers
    # but route params get decoded.
    test_psgi $app, sub {
        my $cb = shift;

        # change the app serializer
        Dancer2->runner->server->apps->[0]->engines->{'serializer'} =
            Dancer2::Serializer::JSON->new;

        my $r = $cb->(
            POST "/from/D\x{c3}\x{bc}sseldorf", # /from/d%C3%BCsseldorf
                'Content-Type' => 'application/json',
                Content        => JSON::to_json({ population => 592393 }),
        );

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

note 'Check serialization errors'; {
    my $serializer = Dancer2::Serializer::JSON->new();
    my $req        = Dancer2::Core::Request->new(
        method       => 'PUT',
        path         => '/from_params',
        content_type => 'application/json',
        body         => "---",
        serializer   => $serializer,
    );

    ok(
        $req->serializer->has_error,
        "Invalid JSON threw error in serializer",
    );

    like(
        $req->serializer->error,
        qr/malformed number/,
        ".. of a 'malformed number'",
    );
}
