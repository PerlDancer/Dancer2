package Dancer2::CLI::Command::version;
# ABSTRACT: display version

use strict;
use warnings;
use App::Cmd::Setup -command;
use Module::Runtime 'require_module';

sub description { 'Display version of Dancer2' }

sub command_names {
    qw/version --version -v/;
}

sub execute {
    require_module('Dancer2');
    print 'Dancer2 ' . Dancer2->VERSION . "\n";
    return 0;
}

1;
