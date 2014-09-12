use Test::More;
use strict;
use warnings;
use File::Temp qw/tempdir/;
use File::Spec;

my $log_dir = tempdir( CLEANUP => 1);

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
    package LogDirNotSpecified;
    use Dancer2;

    set logger  => 'file';
}

subtest 'test Logger::File with log_dir specified' => sub {
    my $app = [ grep { $_->name eq 'LogDirSpecified'} @{ Dancer2->runner->apps }]->[0];

    my $logger = $app->logger_engine;

    is ref($logger), 'Dancer2::Logger::File';
    is $logger->environment, $app->environment;
    is $logger->location, $app->config_location;
    is $logger->log_dir, $log_dir;
    is $logger->file_name, 'test_log.log';
    is $logger->log_file, File::Spec->catfile($log_dir, 'test_log.log');
};

subtest 'test Logger::File with log_dir NOT specified' => sub {
    my $app = [ grep { $_->name eq 'LogDirNotSpecified'} @{ Dancer2->runner->apps }]->[0];

    my $logger = $app->logger_engine;

    my $log_dir = File::Spec->catdir($app->config_location, 'logs');

    is ref($logger), 'Dancer2::Logger::File';
    is $logger->environment, $app->environment;
    is $logger->location, $app->config_location;
    is $logger->log_dir, $log_dir;
    is $logger->file_name, $app->environment.".log";
    is $logger->log_file, File::Spec->catfile($log_dir, $app->environment.'.log');
};

done_testing;
