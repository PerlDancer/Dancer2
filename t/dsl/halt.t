use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

subtest 'halt within routes' => sub {
    {

        package App;
        use Dancer2;

        get '/' => sub { 'hello' };
        get '/halt' => sub {
            header 'X-Foo' => 'foo';
            halt;
        };
        get '/shortcircuit' => sub {
            context->response->content('halted');
            halt;
            redirect '/'; # won't get executed as halt returns immediately.
        };
    }

    my $app = Dancer2->runner->psgi_app;
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
                "Perl Dancer2 $Dancer2::VERSION",
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

subtest 'halt in before hook' => sub {
    {
        package App;
        use Dancer2;

        hook before => sub {
            my $context = shift;
            $context->response->content('I was halted');
            halt if $context->request->dispatch_path eq '/shortcircuit';
        };

    }

    my $app = Dancer2->runner->psgi_app;
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
