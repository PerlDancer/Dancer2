=pod

Same as t/serializer_mutable.t, but exercise the configurable
mappings

=cut

use strict;
use warnings;

use Test::More tests => 5;
use Dancer2::Serializer::Mutable;
use Plack::Test;
use HTTP::Request::Common;
use Encode;
use JSON::MaybeXS;
use YAML;
use Ref::Util qw<is_coderef>;

{
    package Dancer2::Serializer::Other;

    use Moo;
    with 'Dancer2::Core::Role::Serializer';

    has '+content_type' => ( default => 'text/other' );

    sub serialize   { '{thing}' }
    sub deserialize { '{thing}' }

}

{
    package MyApp;
    use Dancer2;

    BEGIN {
        setting engines => { serializer => { Mutable => { mapping => {
            'text/x-yaml'        => 'YAML',
            'text/x-data-dumper' => 'Dumper',
            'text/x-json'        => 'JSON',
            'application/json'   => 'JSON',
            'text/other'         => 'Other',
        } } } };
    }

    use Ref::Util qw<is_hashref>;

    set serializer => 'Mutable';

    get '/serialize'     => sub { +{ bar => 'baz' } };
    post '/deserialize'  => sub {
        return request->data &&
               is_hashref( request->data ) &&
               request->data->{bar} ? { bar => request->data->{bar} } : { ret => '?' };
    };
}

my $app = MyApp->to_app;
ok is_coderef($app), 'Got app';

test_psgi $app, sub {
    my $cb = shift;

    # Configure all test cases
    my $d = {
        yaml    => {
                types       => [ qw(text/x-yaml) ],
                value       => encode('UTF-8', YAML::Dump({ bar => 'baz' })),
                last_val    => "---bar:baz",
            },
        other    => {
                types       => [ qw(text/other) ],
                value       => '{thing}',
                last_val    => "{thing}",
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

    for my $format (keys %$d) {
        subtest "Format: $format" => sub {

            my $s = $d->{$format};

            # Response with implicit call to the serializer
            for my $content_type ( @{ $s->{types} } ) {
                subtest $content_type => sub {
                    for my $ct (qw/Content-Type Accept/) {

                        # Test getting the value serialized in the correct format
                        my $res = $cb->( GET '/serialize', $ct => $content_type );

                        is( $res->code, 200, "status" );
                        is( $res->content, $s->{value}, "content" );
                        is(
                            $res->headers->content_type,
                            $content_type,
                            "content-type headers",
                        );
                    }

                    # Test sending the value serialized in the correct format
                    # needs to be de-serialized and returned
                    my $req = $cb->( POST '/deserialize',
                                        'Content-Type' => $content_type,
                                        content        => $s->{value} );

                    my $content = $req->content;
                    $content =~ s/\s//g;
                    is( $req->code, 200, "status" );
                    is( $content, $s->{last_val}, "content" );
                }
            }
        }
    }

}
