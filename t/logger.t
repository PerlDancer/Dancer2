use Test::More;
use strict;
use warnings;

BEGIN {

    # Freeze time at Tue, 15-Jun-2010 00:00:00 GMT
    *CORE::GLOBAL::time = sub { return 1276560000 }
}

my $_logs = [];

{

    package Dancer2::Logger::Test;
    use Moo;
    with 'Dancer2::Core::Role::Logger';

    sub log {
        my ( $self, $level, $message ) = @_;
        push @$_logs, $self->format_message( $level, $message );
    }
}

my $logger = Dancer2::Logger::Test->new( app_name => 'test' );

is $logger->log_level, 'debug';
$logger->debug("foo");
like $_logs->[0], qr{debug \@2010-06-1\d \d\d:00:00> foo in t/logger.t};

subtest 'logger capture' => sub {
    use Dancer2::Logger::Capture;
    use Dancer2;

    set logger => 'capture';

    warning "Danger!  Warning!";
    info "Tango, Foxtrot";
    debug "I like pie.";

    my $app  = dancer_app;
    my $trap = $app->setting('logger')->trapper;
    is_deeply $trap->read,
      [ { level => "warning", message => "Danger!  Warning!" },
        { level => "info",    message => "Tango, Foxtrot" },
        { level => "debug",   message => "I like pie.", }
      ];

    # each call to read cleans the trap
    is_deeply $trap->read, [];
};

subtest 'logger file' => sub {
    use Dancer2;
    use File::Temp qw/tempdir/;

    my $dir = tempdir( CLEANUP => 1 );

    set engines => {
        logger => {
            File => {
                log_dir   => $dir,
                file_name => 'test',
            }
        }
    };
    # XXX this sucks, we need to set the engine *before* the logger
    # - Franck, 2013/08/03
    set logger  => 'file';

    warning "Danger! Warning!";

    open my $log_file, '<', File::Spec->catfile($dir, 'test');
    my $txt = <$log_file>;
    like $txt, qr/Danger! Warning!/;
};

done_testing;
