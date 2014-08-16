use Test::More;
use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use Capture::Tiny 'capture_stderr';

{
    package App;
    use Dancer2;

    set logger => 'console';

    hook 'before' => sub {
        die "test die inside a before hook";
        print STDERR "error message not caught in the before hook\n";
    };

    get '/' => sub {
        print STDERR "error message not caught in the route handler\n";
    };
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub{
    my $cb = shift;

    my $message = capture_stderr { $cb->( GET "/" ) };

    like $message, qr/test die inside a before hook/;
};

done_testing;
