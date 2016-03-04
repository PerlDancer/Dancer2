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

# Hard to make caller(6) work when we deal with the logger directly,
# so do not check for a specific filename.
like $_logs->[0], qr{debug \@2010-06-1\d \d\d:\d\d:00> foo in };

subtest 'log level and capture' => sub {
    use Dancer2::Logger::Capture;
    use Dancer2;

    # NOTE: this will read the config.yml under t/ that defines log level as info
    set logger => 'capture';

    warning "Danger!  Warning!";
    info "Tango, Foxtrot";
    debug "I like pie.";

    my $trap = dancer_app->engine('logger')->trapper;
    my $msg  = $trap->read;
    delete $msg->[0]{'formatted'};
    delete $msg->[1]{'formatted'};
    is_deeply $msg,
      [
        {
            level => "warning",
            message => "Danger!  Warning!",
        },
        {
            level => "info",
            message => "Tango, Foxtrot",
        },
      ];

    # each call to read cleans the trap
    is_deeply $trap->read, [];
};

subtest 'logger enging hooks' => sub {
    # before hook can change log level or message.
    hook 'engine.logger.before' => sub {
        my $logger = shift; # @_ = ( $level, @message_args )
        $_[0] = 'panic';    # eg. log all messages at the 'panic' level
    };

    my $str = "Thou shalt not pass";
    warning $str;
    my $trap = dancer_app->engine('logger')->trapper;
    my $msg  = $trap->read;
    delete $msg->[0]{'formatted'};
    is_deeply $msg,
      [
        {
            level => "panic",
            message => $str,
        },
    ];
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
# Explicitly close the logger file handle for those systems that
# do not allow "open" files to be unlinked (Windows). GH#424.
my $log_engine = engine('logger');
close $log_engine->fh;

done_testing;
