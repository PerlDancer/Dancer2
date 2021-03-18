package Dancer2::CLI::Gen;
# ABSTRACT: Create new Dancer2 application

use strict;
use warnings;
use Moo;
use CLI::Osprey
    desc => 'Helper script to create new Dancer2 applications';

option application => (
    is            => 'ro',
    short         => 'a',
    doc           => 'application name',
    format        => 's',
    format_doc    => 'appname',
    required      => 1,
    spacer_before => 1,
);

option directory => (
    is         => 'ro',
    short      => 'd',
    doc        => 'application directory (default: same as application name)',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => sub { my $self = shift; return $self->application; },
);

option path => (
    is         => 'ro',
    short      => 'p',
    doc        => 'application path (default: current directory)',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => '.',
);

option overwrite => (
    is       => 'ro',
    short    => 'o',
    doc      => 'overwrite existing files',
    required => 0,
    default  => 0,
);

option nocheck => (
    is       => 'ro',
    option   => 'no-check',
    short    => 'x',
    doc      => "don't check latest Dancer2 version (default: check - requires internet)",
    required => 0,
    default  => 0,
);

# TODO: private dist_dir attr, default to using it
option skel => (
    is         => 'ro',
    short      => 's',
    doc        => 'skeleton directory',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => 0,
);

sub run {
    my $self = shift;

    print "APP: " . $self->application, "\n";
    print "DIR: " . $self->directory, "\n";
    print "PATH: " . $self->path, "\n";
    print "OVERWRITE: " . $self->overwrite, "\n";
    print "NOCHECK: " . $self->nocheck, "\n";
    print "SKEL: " . $self->skel, "\n";
}

1;

