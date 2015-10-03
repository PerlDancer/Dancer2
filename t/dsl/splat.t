use strict;
use warnings;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;

my @splat;

{
    package App;
    use Dancer2;
    get '/*/*/*' => sub {
        my $params = params();
        ::is_deeply(
            $params,
            { splat => [ qw<foo bar baz> ], foo => 42 },
            'Correct params',
        );

        @splat = splat;
    };
}

my $test = Plack::Test->create( App->to_app );
my $res = $test->request( GET '/foo/bar/baz?foo=42' );

is_deeply( [@splat], [qw(foo bar baz)], 'splat behaves as expected' );
is( $res->code, 200, 'got a 200' );
is_deeply( $res->content, 3, 'got expected response' );

