#!perl

use strict;
use warnings;
use Test::More tests => 8;
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


    get '/engine-warning' => sub {
        # Ensure that the logger and warining level is going to be used by the engines, not just the application code
        # Also ensure that the current log level, not the log level when the serialiser is created, is what counts.
        set log        => 'debug';
        set serializer => 'JSON';
        set template   => 'Simple';
        set session    => 'Simple';
        set log        => 'warning';

        foreach my $engine (qw(serializer session template)) {
          app->engine($engine)->log_cb->($_ => "$engine $_ msg\n") for qw(debug warning error);
        }

        return ["engine-warning"];
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
    {
        my $stderr = capture_stderr { $res = $cb->( GET '/engine-warning' ) };

        is( $res->code, 200, 'Successful response' );

        like(
            $stderr,
            qr/
                ^
                # serializer engine should output warning and error only
                \[App:\d+\] \s warning [^\n]+? serializer \s warning [^\n]+ \n
                \[App:\d+\] \s error   [^\n]+? serializer \s error   [^\n]+ \n

                # session engine should output warning and error only
                \[App:\d+\] \s warning [^\n]+? session \s warning [^\n]+ \n
                \[App:\d+\] \s error   [^\n]+? session \s error   [^\n]+ \n

                # template engine should output warning and error only
                \[App:\d+\] \s warning [^\n]+? template \s warning [^\n]+ \n
                \[App:\d+\] \s error   [^\n]+? template \s error   [^\n]+ \n
                $
            /x,
            'Log levels work',
        );
    }
};
