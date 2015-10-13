use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

eval { require AnyEvent; 1; }
    or plan skip_all => 'AnyEvent required for this test';

plan tests => 5;

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

my $caught_error;
{
    package App::ErrorHandler; ## no critic
    use Dancer2;
    require AnyEvent;
    set logger => 'Capture';
    get '/log' => sub {
        delayed {
            flush;
            content "ping\n";
            done;
            content "failure\n";
        };
    };

    get '/cb' => sub {
        delayed {
            flush;
            content "ping\n";
            done;
            content "failure\n";
        } on_error => sub {
            $caught_error = shift;
        };
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

subtest 'Delayed response error handling' => sub {
    my $test = Plack::Test->create( App::ErrorHandler->to_app );

    TODO: {
        local $TODO = 'Does not work in development server';

        my $res = $test->request( GET '/log' );
        ok( $res->is_success, 'Successful request' );
        is( $res->content, "ping\n", 'Correct content' );

        my $logger = App::ErrorHandler::app->logger_engine;
        my $logs   = $logger->trapper->read;
        isa_ok( $logs, 'ARRAY', 'Got logs' );
        is( scalar @{$logs}, 1, 'Got a message' );

        my $msg = shift @{$logs};
        ok( $msg, 'Got message' );
        isa_ok( $msg, 'HASH', 'Got message' );
        is(
            $msg->{'level'},
            'core',
            'Correct error message level',
        );

        like(
            $msg->{'message'},
            qr/^Error in delayed response:/,
            'Got error',
        );
    }

    TODO: {
        local $TODO = 'Does not work in development server';
        my $res = $test->request( GET '/cb' );
        ok( $res->is_success, 'Successful request' );
        is( $res->content, "ping\n", 'Correct content' );
        like( $caught_error, qr/^Error in delayed response:/, 'Got error' );
    }
};
