use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

subtest 'halt with parameter within routes' => sub {
    {

        package App;
        use Dancer2;

        get '/' => sub { 'hello' };
        get '/halt' => sub {
            response_header 'X-Foo' => 'foo';
            halt;
        };
        get '/shortcircuit' => sub {
            halt('halted');
            redirect '/'; # won't get executed as halt returns immediately.
        };
    }

    my $app = App->to_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb = shift;

        {
            my $res = $cb->( GET '/shortcircuit' );
            is( $res->code, 200, '[/shortcircuit] Correct status' );
            is( $res->content, 'halted', '[/shortcircuit] Correct content' );

        }

        {
            my $res = $cb->( GET '/halt' );

            is(
                $res->server,
                "Perl Dancer2 " . Dancer2->VERSION,
                '[/halt] Correct Server header',
            );

            is(
                $res->headers->header('X-Foo'),
                'foo',
                '[/halt] Correct X-Foo header',
            );
        }
    };

};

subtest 'halt with parameter in before hook' => sub {
    {
        package App;
        use Dancer2;

        hook before => sub {
            halt('I was halted') if request->dispatch_path eq '/shortcircuit';
        };

    }

    my $app = App->to_app;
    is( ref $app, 'CODE', 'Got app' );

    test_psgi $app, sub {
        my $cb  = shift;
        my $res = $cb->( GET '/shortcircuit' );

        is( $res->code, 200, '[/shortcircuit] Correct code with before hook' );
        is(
            $res->content,
            'I was halted',
            '[/shortcircuit] Correct content with before hook',
        );
    };
};

done_testing;

