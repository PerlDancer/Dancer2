use strict;
use warnings;

use Test::More;
use Test::Trap;
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
    },
    {   entity  => { error => bless({}, 'invalid') },
        options => {},
        name    => "exception propagates",
    }
);

my $app = Dancer2->runner->psgi_app;

for my $test (@tests) {
    my $expected;
    trap { $expected = JSON::to_json( $test->{entity}, $test->{options} ); };
    my $expected_left = $trap->leaveby();

    # Helpers pass options
    my $actual;
    trap { $actual = Dancer2::Serializer::JSON::to_json( $test->{entity}, $test->{options} ); };
    my $actual_left = $trap->leaveby();
    is( $actual,      $expected,      "to_json: $test->{name}" );
    is( $actual_left, $expected_left, "to_json: $test->{name} lives/dies" );

    # Options from config
    my $serializer = Dancer2::Serializer::JSON->new(config => $test->{options});
    my $output;
    trap { $output = $serializer->serialize( $test->{entity} ); };
    $trap->did_return(); # Serializer not expected to die
    is( $output, $expected, "serialize: $test->{name}" );

    $MyApp::entity = $test->{entity};
    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->( GET '/serialize' );
        if($expected_left eq 'return') {
            is($res->content, $expected,
              "serialized content in response: $test->{name}");
        } else {
            is($res->code, 500,
              "response code for failed serialize: $test->{name}");
            # TODO Add appropriate content test; at the moment this actually
            #      errors out about an undefined variable
        }
    };

}

done_testing();
