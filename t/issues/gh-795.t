use strict;
use warnings;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;
    set serializer => 'Mutable';

    post '/' => sub { request->data };
}

my $test = Plack::Test->create(App->to_app);

is( $test->request( POST '/', Content => "---\nfoo: 42\n", 'Content-Type' => 'text/x-yaml' )->content,
    "---\nfoo: 42\n",
    "Correct YAML content in POST",
);

is( $test->request( POST '/', Content => '{"foo":42}', 'Content-Type' => 'text/x-json' )->content,
    '{"foo":42}',
    "Correct JSON content in POST",
);
