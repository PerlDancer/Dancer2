package Dancer2::CLI::Gen;
# ABSTRACT: Create new Dancer2 application

use strict;
use warnings;
use Moo;
use HTTP::Tiny;
use JSON::MaybeXS;
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

option no_check => (
    is       => 'ro',
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
    default    => '.',
);

# Last chance to validate args before we attempt to do something with them
sub BUILD {
    my ( $self, $args ) = @_;

    my $name = $self->application;
    if ( $name =~ /[^\w:]/ || $name =~ /^\d/ || $name =~ /\b:\b|:{3,}/ ) {
        $self->osprey_usage( 1, qq{ 
Invalid application name. Application names must not contain single colons, 
dots, hyphens or start with a number.
        });
    }

    my $path = $self->path;
    -d $path or $self->osprey_usage( 1, "directory '$path' does not exist" );
    -w $path or $self->osprey_usage( 1, "directory '$path' is not writeable" );

    if ( my $skel = $self->skel ) {
        -d $skel or $self->osprey_usage( 1, "directory '$skel' not found" );
    }
}

sub run {
    my $self = shift;

    $self->_version_check;
    print "D2 VERSION: " . $self->parent_command->_dancer2_version, "\n";
    print "DIST DIR: " . $self->parent_command->_dist_dir, "\n";
    print "APP: " . $self->application, "\n";
    print "DIR: " . $self->directory, "\n";
    print "PATH: " . $self->path, "\n";
    print "OVERWRITE: " . $self->overwrite, "\n";
    print "NOCHECK: " . $self->no_check, "\n";
    print "SKEL: " . $self->skel, "\n";
}

# Other utility methods
sub _version_check {
    my $self    = shift;
    my $version = $self->parent_command->_dancer2_version;
    return if $version =~  m/_/;

    my $latest_version = 0;
    my $resp = HTTP::Tiny->new( timeout => 5 )->get( 'https://fastapi.metacpan.org/release/Dancer2' );
    if( $resp->{ success } ) {
        if ( decode_json( $resp->{ content } )->{ version } =~ /(\d\.\d+)/ ) {
            $latest_version = $1;
        } else {
            die "Can't understand fastapi.metacpan.org's reply.\n";
        }
    }

    if ($latest_version gt $version) {
        print qq{
The latest stable Dancer2 release is $latest_version. You are currently using $version.
Please check https://metacpan.org/pod/Dancer2/ for updates.

};
    }
}

1;

