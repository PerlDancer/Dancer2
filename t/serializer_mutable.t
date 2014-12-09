use strict;
use warnings;

use Test::More tests => 37;
use Dancer2::Serializer::Mutable;
use Plack::Test;
use HTTP::Request;
use Encode;
use JSON;
use YAML;

{
    package MyApp;
    use Dancer2;
    set serializer => 'Mutable';

    post '/' => sub {
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
                value       => JSON::to_json({ bar => 'baz' }),
                last_val    => '{"bar":"baz"}',
            },
    };

    for my $output ( keys %$d ) {
        my $o = $d->{$output};

        for my $o_type ( @{$o->{types}} ) {

            for my $header ( qw/Content-Type Accept/ ) {

                subtest "deserialize $output by $header: $o_type" => sub {
                    my $res = $cb->( HTTP::Request->new(
                        POST => '/',
                        [
                            $header => $o_type,
                        ],
                        $o->{value},
                    ) );

                    is( $res->code                  => 200,     "Correct status" );
                    is( $res->headers->content_type => $o_type, "Correct content-type response header" );

                    my $content = $res->content;
                    $content =~ s/\s//g;
                    is( $content => $o->{last_val}, "Correct content");
                  };
            }

            for my $input ( keys %$d ) {
                my $i = $d->{$input};

                for my $i_type (@{$i->{types}}) {

                    subtest "deserialize from $i_type, serialize to $o_type" => sub {
                        my $res = $cb->( HTTP::Request->new(
                            POST => '/',
                            [
                                'Accept'       => $o_type,
                                'Content-Type' => $i_type,
                            ],
                            $i->{value},
                        ) );

                        is( $res->code                  => 200,     "Correct status" );
                        is( $res->headers->content_type => $o_type, "Correct content-type response header" );

                        my $content = $res->content;
                        $content =~ s/\s//g;
                        is( $content => $o->{last_val}, "Correct content" );
                    };
                }
            } #/ for my $input
        } #/ for my $o_type
    } #/ for my $output

    subtest "default to JSON" => sub {
        my $res = $cb->( HTTP::Request->new(
            POST => '/',
            [
                # no headers
            ],
            $d->{json}{value},
        ) );

        is( $res->code => 200, "Correct status" );
        ok(
            scalar grep( { $res->headers->content_type eq $_ } @{$d->{json}{types}} ),
            "Any correct content-type header"
        );
        is( $res->content => $d->{json}{last_val}, "Correct content" );
    };
  }
