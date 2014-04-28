package Dancer2::CLI::Command::version;
# ABSTRACT: display version

use App::Cmd::Setup -command;

sub description { 'Display version of Dancer2' }

sub command_names {
    qw/version --version -v/;
}

sub execute {
    require Dancer2;
    print 'Dancer2 ' . $Dancer2::VERSION . "\n";
    return 0;
}

1;
