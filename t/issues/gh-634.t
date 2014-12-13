use strict;
use warnings;
use Test::More tests=> 3;
use File::Temp qw/tempdir/;
use File::Spec;

my $log_dir = tempdir( CLEANUP => 1 );

{
    package LogDirSpecified;
    use Dancer2;

    set engines => {
        logger => {
            File => {
                log_dir   => $log_dir,
                file_name => 'test_log.log',
            }
        }
    };
    set logger  => 'file';
}

{
    package NonExistLogDirSpecified;
    use Dancer2;

    set engines => {
        logger => {
            File => {
                log_dir   => "$log_dir/notexist",
                file_name => 'test_log.log',
            }
        }
    };
    set logger  => 'file';
}

{
    package LogDirNotSpecified;
    use Dancer2;

    set logger  => 'file';
}

my $check_cb = sub {
    my ( $app, $dir, $file ) = @_;
    my $logger = $app->logger_engine;

    isa_ok( $logger, 'Dancer2::Logger::File' );
    is(
        $logger->environment,
        $app->environment,
        'Logger got correct environment',
    );

    is(
        $logger->location,
        $app->config_location,
        'Logger got correct location',
    );

    is(
        $logger->log_dir,
        $dir,
        'Logger got correct log directory',
    );

    is(
        $logger->file_name,
        $file,
        'Logger got correct filename',
    );

    is(
        $logger->log_file,
        File::Spec->catfile( $dir, $file ),
        'Logger got correct log file',
    );
};

subtest 'test Logger::File with log_dir specified' => sub {
    plan tests => 6;
    my $app = [
        grep { $_->name eq 'LogDirSpecified' } @{ Dancer2->runner->apps }
    ]->[0];

    $check_cb->( $app, $log_dir, 'test_log.log' );
};

subtest 'test Logger::File with log_dir NOT specified' => sub {
    plan tests => 6;
    my $app = [
        grep { $_->name eq 'LogDirNotSpecified' } @{ Dancer2->runner->apps }
    ]->[0];

    $check_cb->(
        $app,
        File::Spec->catdir( $app->config_location, 'logs' ),
        $app->environment . '.log',
    );
};

subtest 'test Logger::File with non-existent log_dir specified' => sub {
    plan tests => 6;

    my $app = [
        grep { $_->name eq 'NonExistLogDirSpecified'} @{ Dancer2->runner->apps }
    ]->[0];

    my $logger = $app->logger_engine;

    $check_cb->(
        $app,
        "$log_dir/notexist",
        'test_log.log',
    );
};

