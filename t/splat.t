use strict;
use warnings;
use Test::More import => ['!pass'];
use Plack::Test;
use HTTP::Request::Common;

my @splat;

{
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

my $app = Dancer2->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub {
    my $cb  = shift;
    my $res = $cb->( GET '/foo/bar/baz?foo=42' );

    is_deeply( [@splat], [qw(foo bar baz)], 'splat behaves as expected' );
    is( $res->code, 200, 'got a 200' );
    is_deeply( $res->content, 3, 'got expected response' );
};

done_testing;
