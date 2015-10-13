use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    set serializer => 'JSON';

    post '/' => sub { request->data };
}

my $test = Plack::Test->create( App->to_app );

is(
    $test->request( POST '/', Content => '{"foo":42}' )->content,
    '{"foo":42}',
    'Correct JSON content in POST',
);

is(
    $test->request( POST '/', Content => 'invalid' )->code,
    500,
    'Failed to decode invalid content',
);
