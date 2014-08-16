use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Dancer2::Serializer::JSON;

# config
{
    package MyApp;

    use Dancer2;
    our $entity;

    set engines => {
        serializer => {
            JSON => {
                pretty => 1,
            }
        }
    };
    set serializer => 'JSON';

    get '/serialize'  => sub {
        return $entity;
    };
}

my @tests = (
    {   entity  => { a      => 1, b => 2, },
        options => { pretty => 1 },
        name    => "basic hash",
    },
    {   entity  =>
          { c => [ { d => 3, e => { f => 4, g => 'word', } } ], h => 6 },
        options => { pretty => 1 },
        name    => "nested",
    }
);

my $app = Dancer2->psgi_app;

for my $test (@tests) {
    my $expected = JSON::to_json( $test->{entity}, $test->{options} );

    # Helpers pass options
    my $actual =
      Dancer2::Serializer::JSON::to_json( $test->{entity}, $test->{options} );
    is( $actual, $expected, "to_json: $test->{name}" );

    # Options from config
    my $serializer = Dancer2::Serializer::JSON->new(config => $test->{options});
    my $output = $serializer->serialize( $test->{entity} );
    is( $output, $expected, "serialize: $test->{name}" );

    $MyApp::entity = $test->{entity};
    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->( GET '/serialize' );
        is($res->content, $expected,
          "serialized content in response: $test->{name}");
    };

}


done_testing();
