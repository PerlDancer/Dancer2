use strict;
use warnings;

use Test::More;
use Dancer2::ConfigReader;
use Dancer2::FileUtils qw/dirname path/;
use File::Spec;

{
    package Dancer2::ConfigReader::TestWarn;
    use Moo;
    with 'Dancer2::Core::Role::ConfigReader';

    has name => (
        is      => 'ro',
        default => sub { 'TestWarn' },
    );

    has config_data => (
        is      => 'ro',
        default => sub { {} },
    );

    sub read_config {
        my ($self) = @_;
        return $self->config_data;
    }
}

my $location = File::Spec->rel2abs( path( dirname(__FILE__), 'config' ) );

sub _read_config_with_warnings {
    my ($config_data) = @_;

    my $reader = Dancer2::ConfigReader::TestWarn->new(
        environment => 'test',
        location    => $location,
        config_data => $config_data,
    );

    my $cfgr = Dancer2::ConfigReader->new(
        environment    => 'test',
        location       => $location,
        default_config => {},
        config_readers => [$reader],
    );

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    $cfgr->config;

    return join q{}, @warnings;
}

subtest 'warns on unknown keys' => sub {
    my $warnings = _read_config_with_warnings({
        typo => 1,
        engines => {
            logger => {
                File => {
                    log_dir   => '/tmp',
                    log_level => 'debug',
                    extra     => 1,
                },
            },
            template => {
                template_toolkit => {
                    foo => 1,
                },
            },
            serializer => {
                JSON => {
                    allow_nonref => 1,
                    foo          => 2,
                },
            },
        },
    });

    like(
        $warnings,
        qr/Unknown configuration key 'typo'/,
        'warns for unknown top-level key',
    );
    like(
        $warnings,
        qr/Unknown configuration key 'extra' for engine 'logger\/File'/,
        'warns for unknown engine key',
    );
    unlike(
        $warnings,
        qr/template_toolkit/,
        'does not warn for template_toolkit keys',
    );
    unlike(
        $warnings,
        qr/serializer\/JSON/,
        'does not warn for JSON serializer keys',
    );
};

subtest 'can disable warnings' => sub {
    my $warnings = _read_config_with_warnings({
        strict_config => 0,
        typo          => 1,
        engines => {
            logger => {
                File => {
                    extra => 1,
                },
            },
        },
    });

    is( $warnings, q{}, 'warnings silenced' );
};

subtest 'can allow specific top-level keys' => sub {
    my $warnings = _read_config_with_warnings({
        strict_config_allow => [ 'typo', 'extra_top_level' ],
        typo                     => 1,
        extra_top_level          => 1,
        nope                     => 1,
        engines                  => {
            logger => {
                File => {
                    extra => 1,
                },
            },
        },
    });

    unlike(
        $warnings,
        qr/Unknown configuration key 'typo'/,
        'does not warn for allowlisted keys',
    );
    unlike(
        $warnings,
        qr/Unknown configuration key 'extra_top_level'/,
        'does not warn for allowlisted keys',
    );
    like(
        $warnings,
        qr/Unknown configuration key 'nope'/,
        'still warns for other top-level keys',
    );
    like(
        $warnings,
        qr/Unknown configuration key 'extra' for engine 'logger\/File'/,
        'still warns for unknown engine keys',
    );
};

done_testing;
