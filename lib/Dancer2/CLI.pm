package Dancer2::CLI;
# ABSTRACT: Dancer2 CLI application

use strict;
use warnings;
use Moo;
use CLI::Osprey;

subcommand gen => 'Dancer2::CLI::Gen';

sub run {
    my ($self) = @_;
}
1;
