use strict;
use warnings;
use Test::More tests => 1;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::ContentFail; ## no critic
    use Dancer2;
    set show_errors => 1;
    get '/' => sub { content 'Foo' };
}

subtest 'Delayed response overrides content' => sub {
    my $test = Plack::Test->create( App::ContentFail->to_app );
    my $res  = $test->request( GET '/' );
    ok( ! $res->is_success, 'Request failed' );
    is( $res->code, 500, 'Correct response code' );
    like(
        $res->content,
        qr/Cannot use content keyword outside delayed response/,
        'Failed to use content keyword outside delayed response',
    );
};
