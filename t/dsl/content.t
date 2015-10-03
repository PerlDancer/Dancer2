use strict;
use warnings;
use Test::More tests => 1;
use Plack::Test;
use HTTP::Request::Common;

my $logger;
{
    package App::ContentFail; ## no critic
    use Dancer2;
    set show_errors => 1;
    set logger      => 'Capture';

    $logger = app->engine('logger');

    get '/' => sub { content 'Foo' };
}

subtest 'content keyword can only be used within delayed response' => sub {
    my $test = Plack::Test->create( App::ContentFail->to_app );
    my $res  = $test->request( GET '/' );
    ok( ! $res->is_success, 'Request failed' );
    is( $res->code, 500, 'Correct response code' );
    like(
        $res->content,
        qr/Cannot use content keyword outside delayed response/,
        'Failed to use content keyword outside delayed response',
    );

    isa_ok( $logger, 'Dancer2::Logger::Capture' );
    my $trapper = $logger->trapper;
    isa_ok( $trapper, 'Dancer2::Logger::Capture::Trap' );

    my $error = $trapper->read;
    isa_ok( $error, 'ARRAY' );
    is( scalar @{$error}, 1, 'Only one error' );
    ok( delete $error->[0]{'formatted'}, 'Got formatted message' );
    like(
        delete $error->[0]{'message'},
        qr{^\QRoute exception: Cannot use content keyword outside delayed response\E},
        'Correct error message',
    );

    is_deeply(
        $error,
        [ { level => 'error' } ],
        'Rest of error okay',
    );
};
