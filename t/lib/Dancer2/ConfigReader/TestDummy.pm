package Dancer2::ConfigReader::TestDummy;
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
    default => sub {'TestDummy'},
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
    my %config = (
        dummy => {
            dummy_subitem => 2,
        }
    );
    return \%config;
}

1;
