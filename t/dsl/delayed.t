use strict;
use warnings;
use Test::More tests => 4;
use Plack::Test;
use HTTP::Request::Common;

{
    package App::Content; ## no critic
    use Dancer2;
    get '/' => sub {
        ::is( $Dancer2::Core::Route::RESPONDER, undef, 'No responder yet' );

        delayed {
            ::isa_ok(
                $Dancer2::Core::Route::RESPONDER,
                'CODE',
                'Got a responder in the delayed callback',
            );

            ::is( $Dancer2::Core::Route::WRITER, undef, 'No writer yet' );

            content 'OK';
            ::ok( $Dancer2::Core::Route::WRITER, 'Got a writer' );

            done;
        };
    };
}

{
    package App::Content::MultiWrite; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed {
            flush;
            content 'Foo';
            content 'Bar';
            done;
        };
    };
}

{
    package App::NoContent; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed {content;done;'Not OK'};
    };
}

{
    package App::MultipleContent; ## no critic
    use Dancer2;
    get '/' => sub {
        delayed {
            content 'Bar';
            done;
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

subtest 'Testing an app with multiple content keyword calls' => sub {
    my $test = Plack::Test->create( App::Content::MultiWrite->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, 'FooBar', 'Correct content' );
};

subtest 'Testing an app without content keyword' => sub {
    my $test = Plack::Test->create( App::NoContent->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, '', 'Correct content' );
};

subtest 'Delayed response ignored for non-delayed content' => sub {
    my $test = Plack::Test->create( App::MultipleContent->to_app );
    my $res  = $test->request( GET '/' );
    ok( $res->is_success, 'Successful request' );
    is( $res->content, 'OK', 'Correct content' );
};
