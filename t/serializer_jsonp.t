use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Dancer2::Serializer::JSONP;

# config
{
    package MyApp;

    use Dancer2;
    our $entity;

    set engines => {
        serializer => {
            JSONP => {
                pretty => 1,
            }
        }
    };
    set serializer => 'JSONP';

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

my $app = MyApp->to_app;

for my $test (@tests) {
    my $expected = JSON::to_json( $test->{entity}, $test->{options} );

    # Options from config
    my $serializer = Dancer2::Serializer::JSONP->new(config => $test->{options});
    my $output = $serializer->serialize( $test->{entity} );
    is( $output, $expected, "serialize: $test->{name}" );

    $MyApp::entity = $test->{entity};
    test_psgi $app, sub {
        my $cb = shift;
        my $cbname = 'cb'.time;
        my $res = $cb->( GET '/serialize?callback='.$cbname );
        is($res->content, "$cbname($expected);",
          "serialized content in response: $test->{name}");
    };

}


done_testing();
