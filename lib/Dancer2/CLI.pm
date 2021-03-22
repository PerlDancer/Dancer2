package Dancer2::CLI;
# ABSTRACT: Dancer2 CLI application

use Moo;
use CLI::Osprey;
use File::Share 'dist_dir';
use Module::Runtime 'use_module';

subcommand gen => 'Dancer2::CLI::Gen';

# Could have done this one inline, but wanted to remain consistent
# across subcommands.
subcommand version => 'Dancer2::CLI::Version';

# Thinking ahead, these might be useful in future subcommands
has _dancer2_version => (
    is      => 'lazy',
    builder => sub { use_module( 'Dancer2' )->VERSION },
);

has _dist_dir => (
    is      => 'lazy',
    builder => sub{ dist_dir('Dancer2') },
);

sub run {
    my $self = shift;
    return $self->osprey_usage;
}

1;
