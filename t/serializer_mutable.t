use strict;
use warnings;

use Test::More tests => 56;
use Dancer2::Serializer::Mutable;
use Plack::Test;
use HTTP::Request::Common;
use Encode;
use JSON;


{
    package MyApp;

    use Dancer2;

    set serializer => 'Mutable';

    get '/serialize'  => sub {
        return { bar => 'baz' }
    };
    post '/deserialize'  => sub {
        return request->data &&
               ref request->data eq 'HASH' &&
               request->data->{bar} ? request->data->{bar} : '?';
    };
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb = shift;

    # Configure all test cases
    my $d = {
        yaml    => {
                types       => [ qw(text/x-yaml text/html) ],
                value       => encode('UTF-8', YAML::Dump({ bar => 'baz' })),
            },
        dumper  => {
                types       => [ qw(text/x-data-dumper) ],
                value       => Data::Dumper::Dumper({ bar => 'baz' }),
            },
        json    => {
                types       => [ qw(text/x-json application/json) ],
                value       => JSON::to_json({ bar => 'baz' }),
            },
    };

    {
        for my $format (keys %$d) {

            my $s = $d->{$format};

            # Response with implicit call to the serializer
            for my $content_type ( @{ $s->{types} } ) {

                for my $ct (qw/Content-Type Accept Accept-Type/) {

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

                is( $req->code, 200, "[/$format] Correct status" );
                is( $req->content, 'baz', "[/$format] Correct content" );
            } #/ for my $content_type
        } #/ for my $format
    }

}

__END__

=pre

        yaml    => {
                types       => [ qw(text/x-yaml text/html) ],
                value       => "---\nbar: baz\n",
            },

        xml     => {
                types       => [ qw(text/xml) ],
                request     => '',
                response    => '{"bar":"baz"}',
            },
        json    => {
                types       => [ qw(text/x-json application/json) ],
                request     => '',
                response    => '{"bar":"baz"}',
            },







use Test::More import => ['!pass'];
use strict;
use warnings;
use Dancer ':tests';
use Dancer::Test;

BEGIN {
    plan skip_all => 'YAML is needed to run this test'
      unless Dancer::ModuleLoader->load('YAML');
    plan skip_all => 'JSON is needed to run this test'
      unless Dancer::ModuleLoader->load('JSON');
}

plan tests => 10;

setting serializer => 'mutable';

get  '/' => sub { { foo => 1 } };
post '/' => sub { request->params };
post '/echo' => sub { params };

for my $ct (qw/Accept Accept-Type/) {
    my $res = dancer_response(
        GET => '/',
        {
            headers => [ $ct => 'application/json' ]
        }
    );
    is_deeply( from_json( $res->content ), { foo => 1 } );
    is $res->header('Content-Type'), 'application/json';
}

my $res = dancer_response(
    POST => '/',
    {
        params  => { foo => 42 },
        headers => [
            'Content-Type' => 'text/x-yaml',
            'Accept-Type'  => 'text/x-yaml'
        ]
    }
);

is_deeply(from_yaml($res->content), {foo => 42});
is $res->header('Content-Type'), 'text/x-yaml';

# Make sure to grok correct (de)serializer for body params
# when the Content-Type is as supported media type with additional
# parameters.
my $data = { bar => 4711 };
$res = dancer_response(
    POST => '/echo',
    {
        body => to_yaml($data), # make sure to stringify
        # Specifying this content_type is redundant but dancer_response
        # has a bug in that it does not take the Content-Type of the
        # headers before falling back to
        # application/x-www-form-urlencoded :(
        content_type => 'text/x-yaml; charset=utf-8',
        headers => [
            'Content-Type' => 'text/x-yaml; charset=utf-8',
        ]
    }
);
is_deeply( from_yaml( $res->content ), $data );
is $res->header('Content-Type'), 'text/x-yaml; charset=utf-8';

# We were incorrectly using 'Content-Type' also for responses although
# the user told us in 'Accept' to use a different format.
$res = dancer_response(
    POST => '/echo',
    {
        body => to_json($data), # make sure to stringify
        # Specifying this content_type is redundant but dancer_response
        # has a bug in that it does not take the Content-Type of the
        # headers before falling back to
        # application/x-www-form-urlencoded :(
        content_type => 'application/json; charset=utf-8',
        headers => [
            'Content-Type' => 'application/json; charset=utf-8',
            'Accept'       => 'text/x-yaml; charset=utf-8',
        ]
    }
);
is_deeply( from_yaml( $res->content ), $data );
is $res->header('Content-Type'), 'text/x-yaml; charset=utf-8';
=cut
