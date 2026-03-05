use strict;
use warnings;

use Test::More tests => 17;
use Plack::Test;
use HTTP::Request::Common;
use Dancer2::Logger::Capture;

my $logger = Dancer2::Logger::Capture->new;
isa_ok( $logger, 'Dancer2::Logger::Capture' );

{
    package App;
    use Dancer2;

    # default, we're actually overriding this later
    set serializer => 'JSON';

    # for now
    set logger     => 'Console';

    # deserialization fail hook
    hook 'core.error.before' => sub {
        my ($err) = @_;  # Dancer2::Core::Error object
        if ( $err->message =~ m!Failed to deserialize content! ) {
            $err->status(444);  # custom status
        }
    };

    put '/from_params' => sub {
        my %p = params();
        return [ map +( $_ => $p{$_} ), sort keys %p ];
    };

    put '/from_data' => sub {
        my $p = request->data;
        return [ map +( $_ => $p->{$_} ), sort keys %{$p} ];
    };

    # This route is used for both toure and body params.
    post '/from/:town' => sub {
        my $p = params;
        return [ map +( $_ => $p->{$_} ), sort keys %{$p} ];
    };

    any [qw/del patch/] => '/from/:town' => sub {
        my $p = params('body');
        return [ map +( $_ => $p->{$_} ), sort keys %{$p} ];
    };
}

my $test = Plack::Test->create( App->to_app );

subtest 'PUT request with parameters' => sub {
    for my $type ( qw<params data> ) {
        my $res = $test->request(
            PUT "/from_$type",
                'Content-Type' => 'application/json',
                Content        => '{ "foo": 1, "bar": 2 }'
        );

        is(
            $res->content,
            '["bar",2,"foo",1]',
            "Parameters deserialized from $type",
        );
    }
};

my $app = App->to_app;
use utf8;
use JSON::MaybeXS;
use Encode;
use Module::Runtime 'use_module';

note "Verify Serializers decode into characters"; {
    my $utf8 = '∮ E⋅da = Q,  n → ∞, ∑ f(i) = ∏ g(i)';

    test_psgi $app, sub {
        my $cb = shift;

        for my $type ( qw/Dumper JSON YAML/ ) {
            my $class = "Dancer2::Serializer::$type";
            use_module($class);

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

            # Dumper is a jerk and represents it in Perl \x{...} notation

            if ( $type eq 'Dumper' ) {
                {
                    no strict;
                    $content = eval $content;
                }

                # now $content is an actual ref again
                is_deeply(
                    $content,
                    [ 'utf8', $utf8 ],
                    "utf-8 string returns the same using the $type serializer",
                )
            } else {
                like(
                    $content,
                    qr{\Q$utf8\E},
                    "utf-8 string returns the same using the $type serializer",
                );
            }
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
            Content        => JSON::MaybeXS::encode_json({ population => 592393 }),
        );

        my $r = $cb->( POST @req_params );

        # Watch out for hash order randomization..
        is_deeply(
            $r->content,
            '["population",592393,"town","'."D\x{c3}\x{bc}sseldorf".'"]',
            "Integer from JSON body remains integer and route params decoded",
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

        for my $method ( qw/DELETE PATCH/ ) {
            my $request  = HTTP::Request->new(
                $method,
                "/from/D\x{c3}\x{bc}sseldorf", # /from/d%C3%BCsseldorf
                [ 'Content-Type' => 'application/json' ],
                JSON::MaybeXS::encode_json({ population => 592393 }),
            );
            my $response = $cb->($request);
            my $content  = Encode::decode( 'UTF-8', $response->content );

            # Only body params returned
            is(
                $content,
                '["population",592393]',
                "JSON body deserialized for " . uc($method) . " requests",
            );
        }
    }
}

note 'Check serialization errors'; {
    Dancer2->runner->apps->[0]->set_serializer_engine(
        Dancer2::Serializer::JSON->new( log_cb => sub { $logger->log(@_) } )
    );

    test_psgi $app, sub {
        my $cb = shift;

        my $r = $cb->(
            PUT '/from_params',
                'Content-Type' => 'application/json',
                Content        => '---',
        );

        # Ensure error is logged
        my $trap = $logger->trapper;
        isa_ok( $trap, 'Dancer2::Logger::Capture::Trap' );

        my $errors = $trap->read;
        isa_ok( $errors, 'ARRAY' );
        is( scalar @{$errors}, 1, 'One error caught' );

        my $msg = $errors->[0];
        delete $msg->{'formatted'};
        isa_ok( $msg, 'HASH' );
        is( scalar keys %{$msg}, 2, 'Two items in the error' );

        my $err_regex = qr{
            ^
            \QFailed to deserialize content: \E
            \Qmalformed number\E
        }x;

        is( $msg->{'level'}, 'core', 'Correct level' );
        like( $msg->{'message'}, $err_regex, 'Logged correct error message' );

        # Check we get a 444 response
        is( $r->code, 444, "444 custom response" );
        my $content = Dancer2::Serializer::JSON::decode_json( $r->content );
        like( $content->{message}, $err_regex, "Failed to deserialize content error");

    }
}

