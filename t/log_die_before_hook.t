use Test::More;
use strict;
use warnings;
use Plack::Test;
use HTTP::Request::Common;
use File::Temp;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

{
    package App;
    use Dancer2;

    set engines => {
        logger => {
            File => {
                log_dir   => $tempdir,
                file_name => 'test_file'
            }
        }
    };

    set logger => 'file';

    hook 'before' => sub {
        die "test die inside a before hook";
        print STDERR "error message not caught in the before hook\n";
    };

    get '/' => sub {
        die "[test die inside a route handler]";
        print STDERR "error message not caught in the route handler\n";
    };
}

my $app = Dancer2->runner->psgi_app;
is( ref $app, 'CODE', 'Got app' );

test_psgi $app, sub{
    my $cb = shift;

    my $res = $cb->( GET "/" );

    open my $log_file, '<', File::Spec->catfile($tempdir, 'test_file');
    my $log_message = <$log_file>;
    close $log_file;

    like $log_message, qr/test die inside a before hook/;
};

done_testing;
