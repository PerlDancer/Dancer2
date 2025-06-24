package Dancer2::ConfigReader::Recursive;
use Moo;
use Dancer2::Core::Factory;
use Dancer2::Core;
use Dancer2::Core::Types;
use Dancer2::FileUtils 'path';

with 'Dancer2::Core::Role::ConfigReader';

has name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 0,
    default => 'Recursive',
);

has config_files => (
    is      => 'ro',
    lazy    => 1,
    isa     => ArrayRef,
    default => sub {
        my ($self) = @_;
        return [];
    },
);

sub read_config {
    return {
        additional_config_readers => 
            'Dancer2::ConfigReader::Recursive' 
    };
}

1;
