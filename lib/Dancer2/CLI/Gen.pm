package Dancer2::CLI::Gen;
# ABSTRACT: Create new Dancer2 application

use strict;
use warnings;
use Moo;
use HTTP::Tiny;
use JSON::MaybeXS;
use File::Find;
use File::Path 'mkpath';
use File::Spec::Functions qw( catdir catfile );
use File::Basename qw/dirname basename/;
use Dancer2::Template::Simple;
use Module::Runtime qw( require_module is_module_name );
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

option skel => (
    is         => 'ro',
    short      => 's',
    doc        => 'skeleton directory',
    format     => 's',
    format_doc => 'directory',
    required   => 0,
    default    => sub{
        my $self = shift; 
        catdir( $self->parent_command->_dist_dir, 'skel' ); 
    },
);

# Last chance to validate args before we attempt to do something with them
sub BUILD {
    my ( $self, $args ) = @_;

    $self->osprey_usage( 1, qq{ 
Invalid application name. Application names must not contain single colons, 
dots, hyphens or start with a number.
    }) unless is_module_name( $self->application );

    my $path = $self->path;
    -d $path or $self->osprey_usage( 1, "path: directory '$path' does not exist" );
    -w $path or $self->osprey_usage( 1, "path: directory '$path' is not writeable" );

    if ( my $skel = $self->skel ) {
        -d $skel or $self->osprey_usage( 1, "skel: directory '$skel' not found" );
    }
}

sub run {
    my $self = shift;
    $self->_version_check unless $self->no_check;

    my $app_name = $self->application;
    my $app_file = $self->_get_app_file( $app_name );
    my $app_path = $self->_get_app_path( $self->path, $app_name );

    if( my $dir = $self->directory ) {
        $app_path = catdir( $self->path, $dir );
    }

    my $files_to_copy = $self->_build_file_list( $self->skel, $app_path );
    foreach my $pair( @$files_to_copy ) {
        if( $pair->[0] =~ m/lib\/AppFile.pm$/ ) {
            $pair->[1] = catfile( $app_path, $app_file );
            last;
        }
    }

    my $vars = {
        appname          => $app_name,
        appfile          => $app_file,
        appdir           => File::Spec->rel2abs( $app_path ),
        perl_interpreter => $self->_get_perl_interpreter,
        cleanfiles       => $self->_get_dashed_name( $app_name ),
        dancer_version   => $self->parent_command->_dancer2_version,
    };

    $self->_copy_templates( $files_to_copy, $vars, $self->overwrite );
    $self->_create_manifest( $files_to_copy, $app_path );
    $self->_add_to_manifest_skip( $app_path);

    $self->_check_yaml;
    $self->_how_to_run( $app_path );
}

sub _check_yaml {
    if ( ! eval { require_module( 'YAML' ); 1; } ) {
        print qq{
*****

WARNING: YAML.pm is not installed.  This is not a full dependency, but is highly
recommended; in particular, the scaffolded Dancer app being created will not be
able to read settings from the config file without YAML.pm being installed.

To resolve this, simply install YAML from CPAN, for instance using one of the
following commands:

  cpan YAML
  perl -MCPAN -e 'install YAML'
  curl -L https://cpanmin.us | perl - --sudo YAML

*****
};
    }
}

sub _how_to_run {
    my( $self, $app_path ) = @_;
    print qq{
Your new application is ready! To run it:

        cd $app_path
        plackup bin/app.psgi

If you need community assistance, the following resources are available:
- Dancer website: http://perldancer.org
- Mailing list: http://lists.perldancer.org/mailman/listinfo/dancer-users
- IRC: irc.perl.org#dancer

Happy Dancing!

};
}

# skel creation routines
sub _build_file_list {
    my ( $self, $from, $to ) = @_;
    $from   =~ s{/+$}{};
    my $len = length($from) + 1;

    my @result;
    my $wanted = sub {
        return unless -f;
        my $file = substr( $_, $len );

        # ignore .git and git/*
        my $is_git = $file =~ m{^\.git(/|$)}
            and return;

        push @result, [ $_, catfile( $to, $file ) ];
    };

    find({ wanted => $wanted, no_chdir => 1 }, $from );
    return \@result;
}

sub _copy_templates {
    my ( $self, $files, $vars, $overwrite ) = @_;

    foreach my $pair (@$files) {
        my ( $from, $to ) = @{$pair};
        if ( -f $to && !$overwrite ) {
            print "! $to exists, overwrite? [N/y/a]: ";
            my $res = <STDIN>; chomp($res);
            $overwrite = 1 if $res eq 'a';
            next unless ( $res eq 'y' ) or ( $res eq 'a' );
        }

        my $to_dir = dirname( $to );
        if ( ! -d $to_dir ) {
            print "+ $to_dir\n";
            mkpath $to_dir or die "could not mkpath $to_dir: $!";
        }

        my $to_file = basename($to);
        my $ex      = ($to_file =~ s/^\+//);
        $to         = catfile($to_dir, $to_file) if $ex;

        print "+ $to\n";
        my $content;
        {
            local $/;
            open( my $fh, '<:raw', $from ) or die "unable to open file `$from' for reading: $!";
            $content = <$fh>;
            close $fh;
        }

        if( $from !~ m/\.(ico|jpg|png|css|eot|map|swp|ttf|svg|woff|woff2|js)$/ ) {
            $content = _process_template($content, $vars);
        }

        open( my $fh, '>:raw', $to ) or die "unable to open file `$to' for writing: $!";
        print $fh $content;
        close $fh;

        if( $ex ) {
            chmod( 0755, $to ) or warn "unable to change permissions for $to: $!";
        }
    }
}

sub _create_manifest {
    my ( $self, $files, $dir ) = @_;

    my $manifest_name = catfile( $dir, 'MANIFEST' );
    open( my $manifest, '>', $manifest_name ) or die $!;
    print $manifest "MANIFEST\n";

    foreach my $file( @{ $files } ) {
        my $filename       = substr $file->[1], length( $dir ) + 1;
        my $basename       = basename $filename;
        my $clean_basename = $basename;
        $clean_basename    =~ s/^\+//;
        $filename          =~ s/\Q$basename\E/$clean_basename/;
        print {$manifest} "$filename\n";
    }

    close $manifest;
}

sub _add_to_manifest_skip {
    my ( $self, $dir ) = @_;

    my $filename = catfile( $dir, 'MANIFEST.SKIP' );
    open my $fh, '>>', $filename or die $!;
    print {$fh} "^$dir-\n";
    close $fh;
}

sub _process_template {
    my ( $self, $template, $tokens ) = @_;

    my $engine = Dancer2::Template::Simple->new;
    $engine->{ start_tag } = '[d2%';
    $engine->{ stop_tag }  = '%2d]';
    return $engine->render( \$template, $tokens );
}

# These are good candidates to move to Dancer2::CLI if other commands 
# need them later.
sub _get_app_path {
    my ( $self, $path, $appname ) = @_;
    return catdir( $path, $self->_get_dashed_name( $appname ));
}

sub _get_app_file {
    my ( $self, $appname ) = @_;
    $appname =~ s{::}{/}g;
    return catfile( 'lib', "$appname.pm" );
}

sub _get_perl_interpreter {
    return -r '/usr/bin/env' ? '#!/usr/bin/env perl' : "#!$^X";
}

sub _get_dashed_name {
    my ( $self, $name ) = @_;
    $name =~ s{::}{-}g;
    return $name;
}

# Other utility methods
sub _version_check {
    my $self    = shift;
    my $version = $self->parent_command->_dancer2_version;
    return if $version =~  m/_/;

    my $latest_version = 0;
    my $resp = HTTP::Tiny->new( timeout => 5 )->get( 'https://fastapi.metacpan.org/release/Dancer2' );
    if( $resp->{ success } && decode_json( $resp->{ content } )->{ version } =~ /(\d\.\d+)/ ) {
        $latest_version = $1;
        if ($latest_version gt $version) {
            print qq{
The latest stable Dancer2 release is $latest_version. You are currently using $version.
Please check https://metacpan.org/pod/Dancer2/ for updates.

};
        }
    } else {
        warn "\nCouldn't determine latest version of Dancer2. Please check your internet
connection, or use pass -x to gen to bypass this check in the future.\n\n";

    }
}

1;

