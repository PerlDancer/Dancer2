package Dancer2::ConfigReader::Additional;
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
    default => 'Additional',
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
        additional_config_readers => [qw/
            Dancer2::ConfigReader::Config::Any
            Dancer2::ConfigReader::TestDummy
        /]
    };
}

1;
