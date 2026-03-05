use strict;
use warnings;

use Test::More tests => 1;
use Plack::Test;
use Plack::Builder;
use Plack::Request;
use HTTP::Request::Common;
use Encode qw(encode_utf8);

{
    package App;
    use Dancer2;

    # default, we're actually overriding this later
    set serializer => 'JSON';

    # for now
    set logger     => 'Capture';

    post '/json' => sub {
        my $p = body_parameters;
        return [ map +( $_ => $p->get($_) ), sort $p->keys ];
    };
}

my $psgi = builder {
    # inline middleware FTW!
    # Create a Plack::Request object and parse body to tickle #1232
    enable sub {
        my $app = shift;
        sub {
            my $req = Plack::Request->new($_[0])->body_parameters;
            return $app->($_[0]);            
        }
    };
    App->to_app;
};

my $test = Plack::Test->create( $psgi );

subtest 'POST request with parameters' => sub {
    my $characters = encode_utf8("∑∏");
    
    my $res = $test->request(
        POST "/json",
            'Content-Type' => 'application/json',
            'Content'      => qq!{ "foo": 1, "bar": 2, "baz": "$characters" }!
    );

    is(
        $res->content,
        qq!["bar",2,"baz","$characters","foo",1]!,
        "Body parameters deserialized",
    );
};

done_testing();