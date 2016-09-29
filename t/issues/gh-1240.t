use strict;
use warnings;
use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    set serializer => 'JSON';

    post '/' => sub {
        send_as html => to_json(body_parameters->as_hashref, {canonical => 1});
    };
}

my $test = Plack::Test->create( App->to_app );

# something very simple not affected by #1240

is(
    $test->request( POST '/', Content => '{"foo":42}' )->content,
    '{"foo":42}',
    'Correct JSON content in POST',
);

# example from OP in #1240

my $json = q{{"baz":{"foobar":[{"blah":2}]},"foo":[{"bar":1}]}};
is(
    $test->request( POST '/', Content => $json )->content,
    $json,
    'Correct JSON content in POST',
);

# more complex contrived example

$json = q{{"a":[1],"b":[1,2],"c":[{"a":1}],"d":[{"a":1},{"b":2}],"e":1,"f":{"a":1},"g":{"a":1,"b":1},"h":{"a":[1],"b":{"c":1}}}};
is(
    $test->request( POST '/', Content => $json )->content,
    $json,
    'Correct JSON content in POST',
);

done_testing;
