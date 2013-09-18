use strict;
use warnings;

use Test::More tests => 9;

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

use utf8;
use JSON;
use Encode;
use Dancer2::Test apps => ['MyApp'];
use Class::Load 'load_class';

is dancer_response(
    Dancer2::Core::Request->new(
        method       => 'PUT',
        path         => "/from_$_",
        content_type => 'application/json',
        body         => '{ "foo": 1, "bar": 2 }',
        serializer   => Dancer2::Serializer::JSON->new(),
    )
  )->content => 'bar : 2 : foo : 1', "using $_"
  for qw/ params data /;

note "Verify Serializers decode into characters"; {
    my $utf8 = '∮ E⋅da = Q,  n → ∞, ∑ f(i) = ∏ g(i)';

    for my $type ( qw/Dumper JSON YAML/ ) {
        my $class = "Dancer2::Serializer::$type";
        load_class($class);

        my $serializer = $class->new();
        my $body = $serializer->serialize({utf8 => $utf8});

        my $r    = dancer_response(
            Dancer2::Core::Request->new(
                method       => 'PUT',
                path         => '/from_params',
                content_type => $serializer->content_type,
                body         => $body,
                serializer   => $serializer,
            )
        );

        my $content = Encode::decode( 'UTF-8', $r->content );
        is( $content, "utf8 : $utf8", "utf-8 string returns the same using the $type serializer" );
    }
}

note "Decoding of mixed route and deserialized body params"; {
    # Check integers from request body remain integers
    # but route params get decoded.
    my $r = dancer_response( Dancer2::Core::Request->new(
        method       => 'POST',
        path         => "/from/D\x{c3}\x{bc}sseldorf", # /from/d%C3%BCsseldorf
        content_type => 'application/json',
        body         => JSON::to_json({ population => 592393 }),
        serializer   => Dancer2::Serializer::JSON->new(),
    ));

    my $content = Encode::decode( 'UTF-8', $r->content );
    # Watch out for hash order randomization..
    like( $content, qr/[{,]"population":592393/, "Integer from JSON body remains integer" );
    like( $content, qr/[{,]"town":"Düsseldorf"/, "Route params are decoded" );
}

note 'Check serialization errors'; {
    my $serializer = Dancer2::Serializer::JSON->new();
    my $req = Dancer2::Core::Request->new(
        method       => 'PUT',
        path         => '/from_params',
        content_type => 'application/json',
        body         => "---",
        serializer   => $serializer,
    );

    ok $req->serializer->has_error, "Invalid JSON threw error in serializer";
    like $req->serializer->error, qr/malformed number/, ".. of a 'malformed number'";
}
