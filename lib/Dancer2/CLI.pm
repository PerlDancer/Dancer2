package Dancer2::CLI;
# ABSTRACT: Dancer2 CLI application

use strict;
use warnings;
use Moo;
use CLI::Osprey;
use File::Share 'dist_dir';
use Module::Runtime 'require_module';

subcommand gen => 'Dancer2::CLI::Gen';

has _dancer2_version => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        require_module( 'Dancer2' );
        return Dancer2->VERSION;
    },
);

has _dist_dir => (
    is      => 'ro',
    lazy    => 1,
    default => dist_dir('Dancer2'),
);

sub run {
    my ($self) = @_;
}

1;
