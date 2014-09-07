#!perl

use strict;
use warnings;
use Test::More tests => 6;
use Capture::Tiny 0.12 'capture_stderr';
use Plack::Test;
use HTTP::Request::Common;

{
    package App;
    use Dancer2;

    set logger => 'console';
    set log    => 'debug';

    get '/debug' => sub {
        debug   "debug msg\n";
        warning "warning msg\n";
        error   "error msg\n";

        set log => 'warning';

        return 'debug';
    };

    get '/warning' => sub {
        debug   "debug msg\n";
        warning "warning msg\n";
        error   "error msg\n";

        return 'warning';
    };
}

my $app = App->to_app;

test_psgi $app, sub {
    my $cb  = shift;
    my $res;

    {
        my $stderr = capture_stderr { $res = $cb->( GET '/debug' ) };

        is( $res->code,    200,     'Successful response' );
        is( $res->content, 'debug', 'Correct content'     );

        like(
            $stderr,
            qr/
                ^
                # a debug line
                \[App:\d+\] \s debug [^\n]+ \n

                # a warning line
                \[App:\d+\] \s warning [^\n]+ \n

                # followed by an error line
                \[App:\d+\] \s error   [^\n]+ \n
                $
            /x,
            'Log levels work',
        );
    }

    {
        my $stderr = capture_stderr { $res = $cb->( GET '/warning' ) };

        is( $res->code,    200,       'Successful response' );
        is( $res->content, 'warning', 'Correct content'     );

        like(
            $stderr,
            qr/
                ^
                # a warning line
                \[App:\d+\] \s warning [^\n]+ \n

                # followed by an error line
                \[App:\d+\] \s error   [^\n]+ \n
                $
            /x,
            'Log levels work',
        );
    }
};
