use strict;
use warnings;

use Test::More;
use Test::Fatal;
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

my $app = MyApp->to_app;

for my $test (@tests) {
    my $expected;
    my $expected_exception = exception {
        $expected = JSON::to_json( $test->{entity}, $test->{options} );
    };

    # Helpers pass options
    my $actual;
    my $actual_exception = exception {
        $actual = Dancer2::Serializer::JSON::to_json( $test->{entity}, $test->{options} );
    };
    is( $actual,      $expected,      "to_json: $test->{name}" );
    if(defined $expected_exception) {
        # Expect to see the JSON exception somewhere within the thrown one
        like( $actual_exception, qr/\Q$expected_exception\E/, "to_json: $test->{name} dies as expected" );
    } else {
        is( $actual_exception, undef, "to_json: $test->{name} lives" );
    }

    # Options from config
    my $serializer = Dancer2::Serializer::JSON->new(config => $test->{options});
    my $output;
    my $serializer_exception = exception { $output = $serializer->serialize( $test->{entity} ); };
    is( $serializer_exception, undef, "serialize: $test->{name} lives" );
    is( $output, $expected, "serialize: $test->{name}" );

    $MyApp::entity = $test->{entity};
    test_psgi $app, sub {
        my $cb = shift;

        my $res = $cb->( GET '/serialize' );
        if(defined $expected_exception) {
            is($res->code, 500,
              "response code for failed serialize: $test->{name}");
            # TODO Add appropriate content test; at the moment this actually
            #      errors out about an undefined variable
        } else {
            is($res->content, $expected,
              "serialized content in response: $test->{name}");
        }
    };

}

done_testing();
