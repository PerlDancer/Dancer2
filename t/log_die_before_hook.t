use Test::More;
use strict;
use warnings;
use LWP::UserAgent;

use File::Temp;
use Test::TCP 1.13;

my $tempdir = File::Temp::tempdir( CLEANUP => 1, TMPDIR => 1 );

my $server = sub {
    my $port = shift;

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

    # we're overiding a RO attribute only for this test!
    Dancer2->runner->{'port'} = $port;
    start;
};

my $client = sub {
    my $port = shift;
    my $ua = LWP::UserAgent->new;

    my $res = $ua->get("http://127.0.0.1:$port/");

    open my $log_file, '<', File::Spec->catfile($tempdir, 'test_file');
    my $log_message = <$log_file>;
    close $log_file;

    like $log_message, qr/test die inside a before hook/;
};

Test::TCP::test_tcp( client => $client, server => $server);

done_testing;
