package Dancer2::CLI::Version;
# ABSTRACT: Display Dancer2 version

use strict;
use warnings;
use Moo;
use CLI::Osprey
    desc => 'Display version of Dancer2';

sub run {
    my $self = shift;
    print "Dancer2 " . $self->parent_command->_dancer2_version, "\n";
}

1;

