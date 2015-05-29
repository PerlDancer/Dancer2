use strict;
use warnings;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    set serializer => 'JSON';

    put '/data'   => sub { request->data   };
    put '/params' => sub { request->params };
}

my $test = Plack::Test->create( App->to_app );

is(
    $test->request( PUT '/data', Content => '{"foo":"bar"}' )->content,
    '{"foo":"bar"}'
);

is(
    $test->request( PUT '/data', Content => '["foo","bar"]' )->content,
    '["foo","bar"]'
);

is(
    $test->request( PUT '/params', Content => '{"foo":"bar"}' )->content,
    '{"foo":"bar"}'
);

is(
    $test->request( PUT '/params', Content => '["foo","bar"]' )->content,
    '{}'
);
