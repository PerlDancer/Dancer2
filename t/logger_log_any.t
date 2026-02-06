use Test::More;
use strict;
use warnings;

subtest 'logger Log::Any' => sub {
    use Dancer2;
    use File::Temp qw/tempdir/;
    my $dir = tempdir( CLEANUP => 1 );

    set engines => {
        logger => {
            'Log::Any' => {
                category  => 'app-web',
            }
        }
    };
    set logger  => 'Log::Any';
    my $logfile = File::Spec->catfile($dir, 'test');
    use Log::Any::Adapter;
    Log::Any::Adapter->set('File', $logfile);

    my $str = "Logging through Log::Any::Adapter::File";
    info $str;

    open my $log_file, '<', $logfile;
    my $txt = <$log_file>;

    like( $txt, qr/^\[[^\]]+\] $str/, 'Logged string matches');
    my ($hash) = $txt =~ m/^\[[^\]]+\] $str (\{.*\})$/;
    my $h = eval "$hash "; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    is_deeply $h, {
        app_name => "main",
        file => __FILE__,
        line => 23,
        package => "main",
        remote => "-",
        request_id => "-"
    }, 'Info structure matches';

    done_testing;
};

subtest 'logger Log::Any with context' => sub {
    use Dancer2;
    use File::Temp qw/tempdir/;
    my $dir = tempdir( CLEANUP => 1 );

    set engines => {
        logger => {
            'Log::Any' => {
                category  => 'app-web',
            }
        }
    };
    set logger  => 'Log::Any';
    my $logfile = File::Spec->catfile($dir, 'test');
    use Log::Any::Adapter;
    Log::Any::Adapter->set('File', $logfile);

    my $str = "Logging also context through Log::Any::Adapter::File";
    info $str, { seq => 1, trx => 0, critical => 'Yes'  };

    open my $log_file, '<', $logfile;
    my $txt = <$log_file>;

    like( $txt, qr/^\[[^\]]+\] $str/, 'Logged string matches');
    my ($hash) = $txt =~ m/^\[[^\]]+\] $str (\{.*\})$/;
    my $h = eval "$hash "; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    is_deeply $h, {
        app_name => "main",
        file => __FILE__,
        line => 61,
        package => "main",
        remote => "-",
        request_id => "-",
        seq => 1,
        trx => 0,
        critical => 'Yes',
    }, 'Info structure matches';

    done_testing;
};

subtest 'logger Log::Any with complex message and context' => sub {
    use Dancer2;
    use File::Temp qw/tempdir/;
    my $dir = tempdir( CLEANUP => 1 );

    set engines => {
        logger => {
            'Log::Any' => {
                category  => 'app-web',
            }
        }
    };
    set logger  => 'Log::Any';
    my $logfile = File::Spec->catfile($dir, 'test');
    use Log::Any::Adapter;
    Log::Any::Adapter->set('File', $logfile);

    my $str = "Logging also context through Log::Any::Adapter::File";
    info $str, 'more', 'parts', { seq => 2, critical => 'No'  };

    open my $log_file, '<', $logfile;
    my $txt = <$log_file>;

    like( $txt, qr/^\[[^\]]+\] ${str}moreparts/, 'Logged string matches');
    my ($hash) = $txt =~ m/^\[[^\]]+\] ${str}moreparts (\{.*\})$/;
    my $h = eval "$hash "; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    is_deeply $h, {
        app_name => "main",
        file => __FILE__,
        line => 102,
        package => "main",
        remote => "-",
        request_id => "-",
        seq => 2,
        critical => 'No',
    }, 'Info structure matches';

    done_testing;
};

done_testing;
