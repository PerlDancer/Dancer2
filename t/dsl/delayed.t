use strict;
use warnings;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::Content; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed sub {
            content 'OK';
        };
    };
}

{
    package App::NoContent; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed sub {'Not OK'};
    };
}

{
    package App::ContentOverride; ## no critic
    use Dancer2;
    get '/' => sub {
        content 'Foo';
        delayed sub {
            content 'Bar';
        };
    };
}

{
    package App::MultipleContent; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed sub {
            content 'Bar';
        };
        return 'OK';
    };
}

subtest 'Testing an app with content keyword' => sub {
    my $test = Plack::Test->create( App::Content->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, 'OK', 'Correct content' );
};

subtest 'Testing an app without content keyword' => sub {
    my $test = Plack::Test->create( App::NoContent->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '', 'Correct content' );
};

subtest 'Delayed response overrides content' => sub {
    my $test = Plack::Test->create( App::ContentOverride->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, 'Bar', 'Correct content' );
};

subtest 'Delayed response overrides content' => sub {
    my $test = Plack::Test->create( App::MultipleContent->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, 'OK', 'Correct content' );
};
