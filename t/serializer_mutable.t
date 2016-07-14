use strict;
use warnings;

use Test::More tests => 41;
use Dancer2::Serializer::Mutable;
use Plack::Test;
use HTTP::Request::Common;
use Encode;
use JSON::MaybeXS;
use YAML;

{
    package MyApp;
    use Dancer2;
    set serializer => 'Mutable';

    get '/serialize'     => sub { +{ bar => 'baz' } };
    post '/deserialize'  => sub {
        return request->data &&
               ref request->data eq 'HASH' &&
               request->data->{bar} ? { bar => request->data->{bar} } : { ret => '?' };
    };
}

my $app = MyApp->to_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    # Configure all test cases
    my $d = {
        yaml    => {
                types       => [ qw(text/x-yaml text/html) ],
                value       => encode('UTF-8', YAML::Dump({ bar => 'baz' })),
                last_val    => "---bar:baz",
            },
        dumper  => {
                types       => [ qw(text/x-data-dumper) ],
                value       => Data::Dumper::Dumper({ bar => 'baz' }),
                last_val    => "\$VAR1={'bar'=>'baz'};",
            },
        json    => {
                types       => [ qw(text/x-json application/json) ],
                value       => JSON::MaybeXS::encode_json({ bar => 'baz' }),
                last_val    => '{"bar":"baz"}',
            },
    };

    {
        for my $format (keys %$d) {
            note("Format: $format");

            my $s = $d->{$format};

            # Response with implicit call to the serializer
            for my $content_type ( @{ $s->{types} } ) {

                for my $ct (qw/Content-Type Accept/) {

                    # Test getting the value serialized in the correct format
                    my $res = $cb->( GET '/serialize', $ct => $content_type );

                    is( $res->code, 200, "[/$format] Correct status" );
                    is( $res->content, $s->{value}, "[/$format] Correct content" );
                    is(
                        $res->headers->content_type,
                        $content_type,
                        "[/$format] Correct content-type headers",
                    );
                }

                # Test sending the value serialized in the correct format
                # needs to be de-serialized and returned
                my $req = $cb->( POST '/deserialize',
                                 'Content-Type' => $content_type,
                                 content        => $s->{value} );

                my $content = $req->content;
                $content =~ s/\s//g;
                is( $req->code, 200, "[/$format] Correct status" );
                is( $content, $s->{last_val}, "[/$format] Correct content" );
            } #/ for my $content_type
        } #/ for my $format
    }

}
